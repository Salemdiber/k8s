#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-algoarena}"
MASTER_IP="${MASTER_IP:-172.20.10.10}"
FIX_MASTER_IP="${FIX_MASTER_IP:-0}"
APPLY_COREDNS="${APPLY_COREDNS:-0}"

log() {
  printf '\n==> %s\n' "$1"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1"
    exit 1
  fi
}

need_cmd kubectl

log "Checking Kubernetes API"
kubectl version --client >/dev/null

if [ "$FIX_MASTER_IP" = "1" ]; then
  need_cmd ip
  log "Ensuring master IP ${MASTER_IP} exists on this VM"
  if ! ip addr show | grep -q "${MASTER_IP}/"; then
    IFACE="${IFACE:-$(ip route | awk '/default/ {print $5; exit}')}"
    if [ -z "${IFACE}" ]; then
      echo "Cannot detect network interface. Set IFACE=your_interface and retry."
      exit 1
    fi
    sudo ip addr add "${MASTER_IP}/24" dev "${IFACE}"
    sudo systemctl restart kubelet
    sleep 30
  else
    echo "IP ${MASTER_IP} already configured."
  fi
fi

log "Node status"
kubectl get nodes

if [ "$APPLY_COREDNS" = "1" ]; then
  log "Applying CoreDNS manifest"
  kubectl apply -f coredns.yaml
fi

log "Applying AlgoArena manifests"
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-mongo.yaml
kubectl apply -f 03-backend.yaml
kubectl apply -f nginx-config.yaml
kubectl apply -f 04-frontend.yaml
kubectl apply -f 05-ingress.yaml

log "Waiting for rollouts"
kubectl rollout status deployment/mongo -n "${NAMESPACE}" --timeout=180s
kubectl rollout status deployment/algoarena-backend -n "${NAMESPACE}" --timeout=240s
kubectl rollout status deployment/algoarena-frontend -n "${NAMESPACE}" --timeout=180s

log "Pods"
kubectl get pods -n "${NAMESPACE}" -o wide

log "Services"
kubectl get svc,endpoints,ingress -n "${NAMESPACE}"

log "Backend health"
kubectl exec -n "${NAMESPACE}" deploy/algoarena-frontend -- \
  wget -S --spider "http://algoarena-backend:3000/api/system-health"
kubectl exec -n "${NAMESPACE}" deploy/algoarena-frontend -- \
  wget -qO- "http://algoarena-backend:3000/api/system-health"
echo

log "Frontend health"
kubectl exec -n "${NAMESPACE}" deploy/algoarena-frontend -- \
  wget -S --spider "http://algoarena-frontend/"

log "Mongo health"
kubectl exec -n "${NAMESPACE}" deploy/mongo -- \
  mongosh --quiet --eval 'db.adminCommand({ ping: 1 })'

log "Done"
echo "AlgoArena is running."
echo "For local access, add this to /etc/hosts if needed:"
echo "${MASTER_IP} algoarena.local"
