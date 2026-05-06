#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f autoscaling/00-metrics-server.yaml
kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

echo "Waiting for Metrics API..."
for i in $(seq 1 24); do
  if kubectl top nodes >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

kubectl top nodes
kubectl apply -f autoscaling/01-hpa.yaml
kubectl get hpa -n algoarena
