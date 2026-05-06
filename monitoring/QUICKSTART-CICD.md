# Quick Reference: CI/CD Monitoring

## 🚀 Démarrage rapide

### 1. Appliquer la configuration complète

```bash
chmod +x monitoring/apply-monitoring.sh
./monitoring/apply-monitoring.sh
```

### 2. Accéder aux dashboards

**Grafana Dashboard (CI/CD Pipeline):**
```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
# http://localhost:3001/d/cicd-pipeline
# Identifiants: admin / admin
```

**Prometheus:**
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# http://localhost:9090
```

**AlertManager:**
```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# http://localhost:9093
```

## 📊 Que se passe-t-il automatiquement ?

### Build (CI - Jenkinsfile)

✅ Automatiquement exporté:
- Durée du build
- Couverture des tests
- Succès/Échec du build
- Timestamp du build

### Déploiement (CD - Jenkinsfile.cd)

✅ Automatiquement exporté:
- Durée du déploiement
- Succès/Échec du déploiement
- Logs de santé (health checks)

### Alertes

✅ Automatiquement envoyées:
- Email en cas d'échec de build
- Email en cas d'échec de déploiement
- Email si qualité de code faible
- Email si durée de build trop longue

## 📈 Métriques disponibles

### Pour visualiser les métriques

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Puis accéder à `http://localhost:9090` et chercher:

```promql
# Taux de succès des builds (24h)
increase(cicd_build_success_total{job="backend"}[24h]) / 
(increase(cicd_build_success_total{job="backend"}[24h]) + 
 increase(cicd_build_failures_total{job="backend"}[24h]))

# Couverture de tests
cicd_test_coverage_percent{job="backend"}

# Durée du dernier build
cicd_build_duration_seconds{job="backend"}

# Taux de succès des déploiements (24h)
increase(cicd_deployment_success_total{job="backend"}[24h]) / 
(increase(cicd_deployment_success_total{job="backend"}[24h]) + 
 increase(cicd_deployment_failures_total{job="backend"}[24h]))
```

## 🔧 Export manuel de métriques

Si vous voulez exporter manuellement des métriques:

```bash
chmod +x monitoring/export-metrics.sh

# Exemple 1: Exporter une métrique de durée
./monitoring/export-metrics.sh backend cicd_build_duration_seconds 1200

# Exemple 2: Exporter une couverture de test
./monitoring/export-metrics.sh backend cicd_test_coverage_percent 87.5

# Exemple 3: Exporter un compteur
./monitoring/export-metrics.sh backend cicd_build_success_total 1
```

## 🚨 Alertes configurées

| Alerte | Sévérité | Condition | Email |
|--------|----------|-----------|-------|
| BackendBuildFailed | 🔴 Critical | Build échoue | Oui |
| FrontendBuildFailed | 🔴 Critical | Build échoue | Oui |
| BackendDeploymentFailed | 🔴 Critical | Deploy échoue | Oui |
| FrontendDeploymentFailed | 🔴 Critical | Deploy échoue | Oui |
| BuildDurationHigh | 🟡 Warning | Build > 30 min | Oui |
| CodeQualityLow | 🟡 Warning | SonarQube < 70% | Oui |
| DeploymentSuccessRateLow | 🟡 Warning | Succès < 90% en 1h | Oui |
| TestCoverageLow | 🟡 Warning | Coverage < 70% | Oui |

## 📋 Dashboard Grafana

Le dashboard `CI/CD Pipeline Monitoring` affiche:

1. **Build Success Rate (24h)** - Pourcentage de succès
2. **Deployment Success Rate (24h)** - Pourcentage de succès
3. **Test Coverage** - Pourcentage de couverture
4. **Build Duration** - Durée du dernier build
5. **Build Trend (1h)** - Graphique des 60 dernières minutes
6. **Deployment Trend (1h)** - Graphique des 60 dernières minutes
7. **Pipeline Duration Trends** - Tendance des durées

## 🔍 Dépannage

### Aucune métrique n'apparaît dans Prometheus

1. Vérifier que Pushgateway est en cours d'exécution:
   ```bash
   kubectl get pod -n monitoring -l app=prometheus-pushgateway
   ```

2. Vérifier les logs du pod Pushgateway:
   ```bash
   kubectl logs -n monitoring -l app=prometheus-pushgateway
   ```

3. Vérifier les logs Jenkins:
   ```bash
   # Chercher "Exporting metric" ou "cicd_" dans les logs
   ```

### Alertes ne sont pas envoyées

1. Vérifier la configuration du secret Gmail:
   ```bash
   kubectl describe secret alertmanager-gmail -n monitoring
   ```

2. Vérifier les logs d'AlertManager:
   ```bash
   kubectl logs -n monitoring -l app=alertmanager
   ```

### Dashboard Grafana vide

1. Vérifier que Prometheus collecte les données:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus 9090:9090
   # Dans Prometheus, chercher: cicd_build_success_total
   ```

2. Redémarrer Grafana:
   ```bash
   kubectl rollout restart deployment/grafana -n monitoring
   ```

## 📚 Documentation complète

Voir [CICD-INTEGRATION.md](./CICD-INTEGRATION.md) pour plus de détails.

## 💡 Tips

- Les métriques sont conservées 15 jours par défaut dans Prometheus
- Les alertes sont conservées 24h par AlertManager
- Grafana peut conserver jusqu'à 90 jours de données selon le stockage
- Les données du Pushgateway sont perdues si le pod redémarre (utiliser une PersistentVolume pour la production)

## 🔗 Ressources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/overview/)
