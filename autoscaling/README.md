# AlgoArena Autoscaling

Cette configuration installe `metrics-server`, puis cree deux HPA :

- `algoarena-backend`
- `algoarena-frontend`

Les HPA utilisent CPU et memoire :

- backend: min 2, max 4 pods
- frontend: min 2, max 4 pods
- scale up progressif: +1 pod par minute
- scale down prudent: -1 pod toutes les 2 minutes apres stabilisation

## Installation

```bash
chmod +x autoscaling/apply-autoscaling.sh
./autoscaling/apply-autoscaling.sh
```

## Verification

```bash
kubectl top nodes
kubectl top pods -n algoarena
kubectl get hpa -n algoarena
kubectl describe hpa algoarena-backend -n algoarena
kubectl describe hpa algoarena-frontend -n algoarena
```

Note: `k8s-worker1` peut afficher des metriques `<unknown>` tant qu'il est `NotReady`.
