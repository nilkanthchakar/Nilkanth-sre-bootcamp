# Argo CD GitOps Setup

This document shows how to install Argo CD and configure it to manage applications from this repository (including the observability chart).

Prerequisites
- `kubectl` configured for your Minikube cluster
- `helm` installed

Install Argo CD
```bash
# create argocd namespace and install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# wait for server
kubectl -n argocd wait --for=condition=available deployment/argocd-server --timeout=600s
```

Access Argo CD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# open https://localhost:8080
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

Apply repository Application manifests
- The repo contains Argo CD Application manifests in `argocd/`.
- For the observability chart, the deployment and validation steps are documented in [docs/OBSERVABILITY-DEPLOYMENT.md](docs/OBSERVABILITY-DEPLOYMENT.md).
- To deploy the observability Helm chart via Argo CD run:

```bash
kubectl apply -f argocd/observability-helm-application.yaml -n argocd
```

Notes
- The `observability-helm-application.yaml` points to `helm/observability` in this repository. Adjust `targetRevision` if you want a branch or tag other than `main`.
- By default the application sets `useKubePrometheusStack=true` in Helm values; change this in the Argo CD UI or by editing the Application manifest if you prefer the chart-managed mode.
- To remove the Argo CD Application:
```bash
kubectl delete -f argocd/observability-helm-application.yaml -n argocd
```

Troubleshooting
- If an Application is stuck, use `kubectl describe application <name> -n argocd` and check the Argo CD UI for sync errors.
- Ensure the cluster has the `kube-prometheus-stack` CRDs installed when using ServiceMonitors/Probes.
