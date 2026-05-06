#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f monitoring/00-namespace.yaml

if ! kubectl get secret alertmanager-gmail -n monitoring >/dev/null 2>&1; then
  echo "Missing secret: alertmanager-gmail"
  echo
  echo "Create it with your Gmail App Password before applying Alertmanager:"
  echo "kubectl create secret generic alertmanager-gmail \\"
  echo "  -n monitoring \\"
  echo "  --from-literal=from='your-address@gmail.com' \\"
  echo "  --from-literal=username='your-address@gmail.com' \\"
  echo "  --from-literal=app_password='your-google-app-password' \\"
  echo "  --from-literal=to='destination@gmail.com' \\"
  echo "  --dry-run=client -o yaml | kubectl apply -f -"
  exit 1
fi

kubectl apply -f monitoring/01-exporters.yaml
kubectl apply -f monitoring/04-alertmanager.yaml
kubectl apply -f monitoring/02-prometheus.yaml
kubectl apply -f monitoring/05-loki.yaml
kubectl apply -f monitoring/03-grafana.yaml
kubectl apply -f monitoring/06-prometheus-pushgateway.yaml
kubectl apply -f monitoring/06-cicd-rules.yaml
kubectl apply -f monitoring/07-cicd-servicemonitor.yaml
kubectl apply -f monitoring/08-cicd-grafana-dashboard.yaml

kubectl wait pod -n monitoring -l app=node-exporter --field-selector spec.nodeName=k8s-master --for=condition=Ready --timeout=180s
kubectl rollout status deployment/kube-state-metrics -n monitoring --timeout=180s
kubectl rollout status deployment/blackbox-exporter -n monitoring --timeout=180s
kubectl rollout status deployment/alertmanager -n monitoring --timeout=180s
kubectl rollout status deployment/prometheus-pushgateway -n monitoring --timeout=180s
kubectl rollout status deployment/prometheus -n monitoring --timeout=180s
kubectl rollout status deployment/loki -n monitoring --timeout=180s
kubectl rollout status daemonset/promtail -n monitoring --timeout=180s || true
kubectl rollout status deployment/grafana -n monitoring --timeout=180s

kubectl get pods,svc -n monitoring

echo
echo "Grafana:    kubectl port-forward -n monitoring svc/grafana 3001:3000"
echo "Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "Pushgateway: kubectl port-forward -n monitoring svc/prometheus-pushgateway 9091:9091"
echo "Alerts:     kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
echo "Loki:       kubectl port-forward -n monitoring svc/loki 3100:3100"
echo "Grafana login: admin / admin"
echo ""
echo "CI/CD Dashboard: http://localhost:3001/d/cicd-pipeline"
