# k8s

A collection of Kubernetes (k8s) resources and helper scripts.

## What’s in this repo
This repository is intended to store Kubernetes-related assets such as:
- Manifests (Deployments, Services, Ingress, ConfigMaps, Secrets, etc.)
- Helm charts (if/when added)
- Shell scripts to automate common Kubernetes tasks

> Note: The repo currently shows **Shell** as its primary language, which typically means it contains (or will contain) operational scripts.

## Prerequisites
- A Kubernetes cluster (local or remote)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) installed and configured
- (Optional) [`helm`](https://helm.sh/docs/intro/install/) if you add charts

Check cluster access:

```sh
kubectl version --client
kubectl cluster-info
```

## Recommended repo structure
If you’re organizing raw manifests, a structure like this scales well:

```text
k8s/
  manifests/
    apps/
    infra/
  helm/
  scripts/
  docs/
```

## Usage
### Apply manifests
Apply a single file:

```sh
kubectl apply -f path/to/manifest.yaml
```

Apply a directory:

```sh
kubectl apply -f manifests/
```

### Delete resources

```sh
kubectl delete -f manifests/
```

## Common commands
View workloads:

```sh
kubectl get ns
kubectl get pods -A
kubectl get deploy -A
kubectl get svc -A
```

Describe and debug:

```sh
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=200
kubectl exec -it <pod-name> -n <namespace> -- sh
```

## Scripts
If you add scripts under `scripts/`, keep them:
- idempotent when possible
- documented with `--help` or usage comments at the top

Example run pattern:

```sh
bash scripts/<script>.sh
```

## Contributing
1. Create a branch
2. Make your changes
3. Open a pull request

If you’re adding cluster-specific values, consider using templates and keeping secrets out of Git.

## License
No license file is currently included. If you want this to be open-source-friendly, consider adding a `LICENSE` (MIT/Apache-2.0 are common choices).
