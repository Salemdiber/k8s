# CI/CD Integration avec Monitoring

Cette documentation explique comment le pipeline CI/CD est intégré avec la stack de monitoring Prometheus/Grafana/AlertManager.

## Architecture

### Flux d'intégration

```
Jenkins Pipeline (CI/CD)
    ↓
Prometheus Pushgateway
    ↓
Prometheus (scrape)
    ↓
AlertManager (si seuil dépassé)
    ↓
Grafana (dashboard + visualisation)
    ↓
Email/Notifications (via AlertManager)
```

## Métriques collectées

### Métriques de Build (CI)

- `cicd_build_success_total` : Nombre total de builds réussis
- `cicd_build_failures_total` : Nombre total de builds échoués
- `cicd_build_duration_seconds` : Durée du build en secondes
- `cicd_test_coverage_percent` : Pourcentage de couverture de tests
- `cicd_build_timestamp` : Timestamp du build

### Métriques de Déploiement (CD)

- `cicd_deployment_success_total` : Nombre total de déploiements réussis
- `cicd_deployment_failures_total` : Nombre total de déploiements échoués
- `cicd_deployment_duration_seconds` : Durée du déploiement en secondes

### Métriques de Qualité de Code

- `cicd_sonarqube_quality_gate` : Score SonarQube quality gate

## Alertes configurées

### Alertes critiques

1. **BackendBuildFailed** : Le build backend a échoué
2. **FrontendBuildFailed** : Le build frontend a échoué
3. **BackendDeploymentFailed** : Le déploiement backend a échoué
4. **FrontendDeploymentFailed** : Le déploiement frontend a échoué

### Alertes d'avertissement

1. **BuildDurationHigh** : La durée du build dépasse 30 minutes
2. **CodeQualityLow** : Le score de qualité SonarQube est inférieur à 70%
3. **DeploymentSuccessRateLow** : Le taux de succès de déploiement < 90% sur 1h
4. **TestCoverageLow** : La couverture de tests est inférieure à 70%

## Configuration Jenkins

### Variables d'environnement

Les pipelines Jenkins utilisent les variables suivantes :

```bash
PROMETHEUS_PUSHGATEWAY = 'prometheus-pushgateway.monitoring.svc.cluster.local:9091'
ALERTMANAGER_URL = 'http://alertmanager.monitoring.svc.cluster.local:9093/api/v1/alerts'
JOB_NAME = 'algoarena-backend-ci'  # ou 'algoarena-backend-cd'
```

### Étapes d'export des métriques

#### Dans le stage 'Test and coverage' (Jenkinsfile)

```groovy
// Les métriques de couverture sont automatiquement extraites du rapport de couverture
coverage=$(grep -oP 'statements":\\s*\\{[^}]*"pct":\\s*\\K[^,]+' coverage/coverage-summary.json)
```

#### Dans le post hook success/failure

```groovy
// Export des métriques au Pushgateway
curl -d @- http://\$PROMETHEUS_PUSHGATEWAY/metrics/job/\$CI_JOB_NAME

// Envoi des alertes à AlertManager
curl -X POST -H "Content-Type: application/json" \\
  -d '{...alert payload...}' \\
  \$ALERTMANAGER_URL
```

## Dashboard Grafana

### Pannels disponibles

1. **Backend Build Success Rate (24h)** : Taux de succès des builds sur 24h
2. **Backend Deployment Success Rate (24h)** : Taux de succès des déploiements sur 24h
3. **Backend Test Coverage** : Pourcentage de couverture de tests
4. **Backend Build Duration** : Durée du dernier build
5. **Build Trend (1h)** : Tendance des builds réussis/échoués sur 1h
6. **Deployment Trend (1h)** : Tendance des déploiements réussis/échoués sur 1h
7. **Pipeline Duration Trends** : Tendance des durées de build et déploiement

### Accès au dashboard

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Puis naviguer vers : `http://localhost:3001/d/cicd-pipeline`

Identifiants : `admin / admin`

## Intégration avec AlertManager

### Configuration email

Les alertes sont envoyées par email via AlertManager. Configuration requise :

```bash
kubectl create secret generic alertmanager-gmail \
  -n monitoring \
  --from-literal=from='your-address@gmail.com' \
  --from-literal=username='your-address@gmail.com' \
  --from-literal=app_password='your-google-app-password' \
  --from-literal=to='destination@gmail.com'
```

### Webhooks personnalisés

Pour intégrer avec Slack, Teams, ou d'autres services :

Modifier le fichier `04-alertmanager.yaml` pour ajouter des receivers webhook.

## Fichiers d'intégration

- `06-cicd-rules.yaml` : Règles d'alertes Prometheus pour CI/CD
- `07-cicd-servicemonitor.yaml` : Configuration de scrape pour Jenkins/SonarQube
- `08-cicd-grafana-dashboard.yaml` : Dashboard Grafana pour CI/CD
- `back_jenkins/Jenkinsfile` : Pipeline CI avec export de métriques
- `back_jenkins/Jenkinsfile.cd` : Pipeline CD avec export de métriques et notifications

## Installation

```bash
# Appliquer toutes les configurations (y compris CI/CD)
chmod +x monitoring/apply-monitoring.sh
./monitoring/apply-monitoring.sh
```

## Dépannage

### Prometheus ne collecte pas les métriques de Jenkins

1. Vérifier que Pushgateway est accessible
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-pushgateway 9091:9091
   curl http://localhost:9091/metrics
   ```

2. Vérifier les logs Jenkins
   ```bash
   kubectl logs -f deployment/jenkins -n jenkins
   ```

### Alertes ne sont pas envoyées

1. Vérifier AlertManager
   ```bash
   kubectl port-forward -n monitoring svc/alertmanager 9093:9093
   # Puis visiter http://localhost:9093
   ```

2. Vérifier la configuration email
   ```bash
   kubectl describe secret alertmanager-gmail -n monitoring
   ```

### Dashboard Grafana vide

1. Vérifier que Prometheus a collecté les métriques
   ```bash
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   # Puis chercher "cicd_build" dans Prometheus
   ```

2. Redémarrer Grafana
   ```bash
   kubectl rollout restart deployment/grafana -n monitoring
   ```

## Extension

Pour ajouter d'autres métriques :

1. Exporter les métriques depuis Jenkins
   ```bash
   curl -d @- http://$PROMETHEUS_PUSHGATEWAY/metrics/job/$JOB_NAME << EOF
   # HELP my_custom_metric Description
   # TYPE my_custom_metric gauge
   my_custom_metric{label="value"} 123
   EOF
   ```

2. Ajouter les règles d'alerte dans `06-cicd-rules.yaml`

3. Ajouter les panels dans `08-cicd-grafana-dashboard.yaml`

## Ressources

- [Prometheus Pushgateway](https://github.com/prometheus/pushgateway)
- [AlertManager Webhooks](https://prometheus.io/docs/alerting/latest/webhook_receiver/)
- [Grafana Dashboards](https://grafana.com/docs/grafana/latest/dashboards/)
