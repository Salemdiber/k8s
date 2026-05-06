#!/usr/bin/env bash
# Export CI/CD metrics manually to Prometheus Pushgateway
# Usage: ./export-metrics.sh <job_name> <metric_name> <value> [labels]
# Example: ./export-metrics.sh backend cicd_build_duration_seconds 1234
# Example: ./export-metrics.sh backend cicd_test_coverage_percent 85.5 "status=\"success\""

set -euo pipefail

PROMETHEUS_PUSHGATEWAY="${PROMETHEUS_PUSHGATEWAY:-prometheus-pushgateway.monitoring.svc.cluster.local:9091}"
NAMESPACE="${NAMESPACE:-monitoring}"

# Check if running inside cluster
if ! kubectl cluster-info &>/dev/null; then
  echo "Error: Not connected to a Kubernetes cluster"
  exit 1
fi

# Get pushgateway pod for port-forward if not accessible
if ! curl -s http://$PROMETHEUS_PUSHGATEWAY/metrics &>/dev/null; then
  echo "Prometheus Pushgateway not accessible at $PROMETHEUS_PUSHGATEWAY"
  echo "Attempting to port-forward..."
  
  PUSHGATEWAY_POD=$(kubectl get pod -n $NAMESPACE -l app=prometheus-pushgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [ -z "$PUSHGATEWAY_POD" ]; then
    echo "Error: No Pushgateway pod found in namespace $NAMESPACE"
    exit 1
  fi
  
  # Try port-forward in background
  kubectl port-forward -n $NAMESPACE svc/prometheus-pushgateway 9091:9091 &>/dev/null &
  PORTFORWARD_PID=$!
  sleep 2
  
  PROMETHEUS_PUSHGATEWAY="localhost:9091"
  
  trap "kill $PORTFORWARD_PID 2>/dev/null || true" EXIT
fi

# Check arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <job_name> <metric_name> <value> [labels]"
  echo ""
  echo "Examples:"
  echo "  $0 backend cicd_build_duration_seconds 1234"
  echo "  $0 backend cicd_test_coverage_percent 85.5"
  echo "  $0 backend cicd_build_success_total 1 'status=\"success\"'"
  exit 1
fi

JOB_NAME="$1"
METRIC_NAME="$2"
METRIC_VALUE="$3"
METRIC_LABELS="${4:-}"

# Validate metric value is a number
if ! [[ "$METRIC_VALUE" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  echo "Error: Metric value must be a number, got: $METRIC_VALUE"
  exit 1
fi

# Build metric line
if [ -n "$METRIC_LABELS" ]; then
  METRIC_LINE="$METRIC_NAME{$METRIC_LABELS} $METRIC_VALUE"
else
  METRIC_LINE="$METRIC_NAME $METRIC_VALUE"
fi

# Send to Pushgateway
echo "Exporting metric to Pushgateway: $PROMETHEUS_PUSHGATEWAY"
echo "Job: $JOB_NAME"
echo "Metric: $METRIC_LINE"
echo ""

curl -s -X POST --data-binary "$METRIC_LINE" \
  "http://$PROMETHEUS_PUSHGATEWAY/metrics/job/$JOB_NAME" && echo "✓ Metric exported successfully" || echo "✗ Failed to export metric"
