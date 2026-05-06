#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="$ROOT_DIR/monitoring"
NAMESPACE="${NAMESPACE:-monitoring}"
ALERTMANAGER_HOST="${ALERTMANAGER_HOST:-127.0.0.1}"
ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}"
ALERTMANAGER_URL="http://${ALERTMANAGER_HOST}:${ALERTMANAGER_PORT}"
PORT_FORWARD_PID=""

log() {
  printf '\n==> %s\n' "$1"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing command: $1"
    exit 1
  fi
}

cleanup() {
  if [[ -n "$PORT_FORWARD_PID" ]]; then
    kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

need_cmd kubectl
need_cmd curl

log "Applying monitoring stack"
bash "$MONITORING_DIR/apply-monitoring.sh"

if curl -sSf "$ALERTMANAGER_URL/-/ready" >/dev/null 2>&1; then
  log "Alertmanager is already reachable at $ALERTMANAGER_URL"
else
  log "Starting local port-forward to Alertmanager"
  kubectl port-forward -n "$NAMESPACE" svc/alertmanager "$ALERTMANAGER_PORT:9093" >/tmp/alertmanager-port-forward.log 2>&1 &
  PORT_FORWARD_PID=$!

  for _ in $(seq 1 30); do
    if curl -sSf "$ALERTMANAGER_URL/-/ready" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  curl -sSf "$ALERTMANAGER_URL/-/ready" >/dev/null
fi

log "Sending fake alerts"
cat << 'EOF' | curl -s -X POST -H "Content-Type: application/json" -d @- "$ALERTMANAGER_URL/api/v2/alerts"
[
  {
    "labels": {
      "alertname": "FakeBackendDegraded",
      "severity": "critical",
      "job": "backend",
      "namespace": "algoarena",
      "deployment": "algoarena-backend",
      "instance": "backend-1"
    },
    "annotations": {
      "summary": "Fake backend degradation alert",
      "description": "A fake critical alert to test routing and notifications"
    },
    "startsAt": "2026-05-05T00:00:00Z",
    "endsAt": "0001-01-01T00:00:00Z",
    "generatorURL": "http://localhost/test"
  },
  {
    "labels": {
      "alertname": "FakeFrontendLatency",
      "severity": "warning",
      "job": "frontend",
      "namespace": "algoarena",
      "deployment": "algoarena-frontend",
      "instance": "frontend-1"
    },
    "annotations": {
      "summary": "Fake frontend latency alert",
      "description": "A fake warning alert to test Alertmanager"
    },
    "startsAt": "2026-05-05T00:00:00Z",
    "endsAt": "0001-01-01T00:00:00Z",
    "generatorURL": "http://localhost/test"
  },
  {
    "labels": {
      "alertname": "FakeDatabaseUnreachable",
      "severity": "critical",
      "job": "mongo",
      "namespace": "algoarena",
      "deployment": "mongo",
      "instance": "mongo-1"
    },
    "annotations": {
      "summary": "Fake database unreachable alert",
      "description": "A fake database alert to test notification delivery"
    },
    "startsAt": "2026-05-05T00:00:00Z",
    "endsAt": "0001-01-01T00:00:00Z",
    "generatorURL": "http://localhost/test"
  }
]
EOF

log "Checking active alerts"
curl -s "$ALERTMANAGER_URL/api/v2/alerts" | grep -o '"alertname":"[^"]*"' | sort -u

log "Done"
echo "Alertmanager is available at: $ALERTMANAGER_URL"
echo "Open http://$ALERTMANAGER_HOST:$ALERTMANAGER_PORT in your browser"