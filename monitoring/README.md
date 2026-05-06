# AlgoArena Monitoring

Cette stack installe une base monitoring Kubernetes pour AlgoArena :

- Prometheus collecte les metriques.
- Alertmanager recoit les alertes Prometheus.
- Loki centralise les logs.
- Promtail collecte les logs des pods Kubernetes.
- Grafana affiche le dashboard `AlgoArena Overview`.
- node-exporter expose les metriques CPU/RAM/disque du node.
- kube-state-metrics expose l'etat Kubernetes des pods/deployments.
- blackbox-exporter teste les endpoints HTTP frontend et backend.

## Installation

```bash
chmod +x monitoring/apply-monitoring.sh
./monitoring/apply-monitoring.sh
```

Pour tout lancer d'un coup puis envoyer des alertes factices:

```bash
chmod +x launch-monitoring-fake-alert.sh
./launch-monitoring-fake-alert.sh
```

## Acces local

Grafana :

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Puis ouvre :

```text
http://localhost:3001
```

Identifiants par defaut :

```text
admin / admin
```

Prometheus :

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Puis ouvre :

```text
http://localhost:9090
```

Alertmanager :

```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

Puis ouvre :

```text
http://localhost:9093
```

La configuration actuelle envoie les alertes vers Gmail via le receiver `gmail`.
Avant de lancer Alertmanager, cree le secret avec ton adresse Gmail et un App Password Google :

```bash
kubectl create secret generic alertmanager-gmail \
  -n monitoring \
  --from-literal=from='ton-adresse@gmail.com' \
  --from-literal=username='ton-adresse@gmail.com' \
  --from-literal=app_password='xxxx xxxx xxxx xxxx' \
  --from-literal=to='destination@gmail.com' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Il faut utiliser un App Password Gmail, pas le mot de passe normal du compte Google.

Loki :

```bash
kubectl port-forward -n monitoring svc/loki 3100:3100
```

Dans Grafana, la datasource `Loki` est provisionnee automatiquement.

Requetes LogQL utiles :

```logql
{namespace="algoarena"}
{namespace="algoarena", app="algoarena-backend"}
{namespace="algoarena", app="algoarena-frontend"}
```

## Requetes utiles Prometheus

Backend health :

```promql
probe_success{instance="http://algoarena-backend.algoarena.svc.cluster.local:3000/api/system-health"}
```

Frontend health :

```promql
probe_success{instance="http://algoarena-frontend.algoarena.svc.cluster.local/"}
```

Replicas disponibles :

```promql
kube_deployment_status_replicas_available{namespace="algoarena"}
```

Memoire node :

```promql
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

Alertes actives :

```promql
ALERTS{alertstate="firing"}
```
