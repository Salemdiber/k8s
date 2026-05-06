#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-algoarena}"

log() {
  printf '\n========================================\n%s\n========================================\n' "$1"
}

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
  echo "❌ kubectl not found. Please install kubectl."
  exit 1
fi

# Try to connect to the cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "❌ Cannot connect to Kubernetes cluster. Check your kubeconfig."
  exit 1
fi

log "🔍 CLUSTER NODES STATUS"
kubectl get nodes -o wide
echo ""
kubectl describe nodes | grep -E "Name:|Status:|Capacity:|Allocatable:|Images:" | head -20

log "🔍 NAMESPACE OVERVIEW"
kubectl get namespaces

log "🔍 PODS IN NAMESPACE: $NAMESPACE"
kubectl get pods -n "$NAMESPACE" -o wide
echo ""
kubectl get pods -n "$NAMESPACE" -o json | jq '.items[] | {name: .metadata.name, phase: .status.phase, containers: [.spec.containers[].name], ready: .status.conditions[] | select(.type=="Ready") | .status}' 2>/dev/null || echo "Unable to parse pod details"

log "🔍 DEPLOYMENT STATUS"
kubectl get deployments -n "$NAMESPACE" -o wide
echo ""
kubectl describe deployments -n "$NAMESPACE" | grep -E "Name:|Replicas:|Ready:|Updated:|Available:|Conditions:" -A 5

log "🔍 STATEFULSETS"
kubectl get statefulsets -n "$NAMESPACE" -o wide

log "🔍 PODS EVENTS (Last 10 events)"
kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10

log "🔍 POD RESOURCE USAGE"
if kubectl top pods -n "$NAMESPACE" >/dev/null 2>&1; then
  kubectl top pods -n "$NAMESPACE" --containers
else
  echo "⚠️  Metrics not available (metrics-server may not be installed)"
fi

log "🔍 NODE RESOURCE USAGE"
if kubectl top nodes >/dev/null 2>&1; then
  kubectl top nodes
else
  echo "⚠️  Node metrics not available"
fi

log "🔍 SERVICES AND ENDPOINTS"
kubectl get svc,endpoints -n "$NAMESPACE" -o wide

log "🔍 PERSISTENT VOLUMES"
kubectl get pv,pvc -n "$NAMESPACE" -o wide

log "🔍 INGRESS"
kubectl get ingress -n "$NAMESPACE" -o wide

log "🔍 UNHEALTHY PODS (if any)"
unhealthy=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded -o name 2>/dev/null)
if [ -z "$unhealthy" ]; then
  echo "✅ All pods are healthy (Running or Succeeded)"
else
  echo "⚠️  Unhealthy pods found:"
  echo "$unhealthy" | while read pod; do
    echo ""
    echo "Pod: $pod"
    kubectl describe "$pod" -n "$NAMESPACE" | grep -E "State:|Reason:|Message:|Last State:" | head -10
  done
fi

log "🔍 BACKEND REPLICA SET"
kubectl get replicasets -n "$NAMESPACE" -l app=algoarena-backend -o wide

log "🔍 BACKEND POD LOGS (Last pod)"
backend_pod=$(kubectl get pods -n "$NAMESPACE" -l app=algoarena-backend -o name | head -1)
if [ -n "$backend_pod" ]; then
  echo "Latest logs from: $backend_pod"
  kubectl logs "$backend_pod" -n "$NAMESPACE" --tail=20
fi

log "✅ WORKER VERIFICATION COMPLETE"
