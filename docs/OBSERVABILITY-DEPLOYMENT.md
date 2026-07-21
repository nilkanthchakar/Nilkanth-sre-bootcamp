# Observability Deployment Guide

This repo contains `helm/observability`, a lightweight observability Helm chart (Prometheus, Grafana, Loki, Promtail, exporters). You have two deployment options:

1) Lightweight Helm chart (built-in Prometheus & exporters)
2) Prometheus Operator (`kube-prometheus-stack`) — recommended for production

Common prerequisites
- `kubectl` connected to cluster (Minikube in this repo)
- `helm` installed
- For production, have a default `StorageClass` available before enabling persistence
- A node labeled for dependent services (optional but recommended)

Label node (optional)
```bash
kubectl label node <node-name> dependent_services=true
```

Option A — Install lightweight chart (quick start)
```bash
# create namespace and install
helm upgrade --install observability ./helm/observability -n observability --create-namespace
```

Secrets
- Create a Kubernetes Secret for Postgres exporter credentials (replace values):
```bash
kubectl -n observability create secret generic pg-exporter-creds \
  --from-literal=DATA_SOURCE_NAME='postgresql://postgres:MY_PASSWORD@student-db:5432/studentdb?sslmode=disable'
```

Option B — Use Prometheus Operator (recommended)
1. Install the operator (example chart):
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n observability --create-namespace
```
2. Disable built-in Prometheus/exporters in this chart and install via Argo CD or Helm:
```bash
helm upgrade --install observability ./helm/observability -n observability --set useKubePrometheusStack=true
```
3. If you want to manage the chart from a values file instead, set the same flag there and disable any duplicate metrics components you do not want to run twice.

Argo CD GitOps (optional)
- Apply the Argo CD Application manifest in `argocd/observability-helm-application.yaml` to let Argo CD manage the chart.

Validation
```bash
kubectl get pods -n observability
kubectl get svc -n observability
kubectl get servicemonitors,probes -n observability   # if using operator
kubectl port-forward svc/grafana -n observability 3000:3000
kubectl port-forward svc/prometheus -n observability 9090:9090
# open http://localhost:3000 (admin/admin default)
# open http://localhost:9090 to confirm Prometheus targets are healthy
```

Notes
- Promtail is configured to scrape only the namespace set in `values.yaml` (`applicationNamespace`). Update that value to change which logs are sent to Loki.
- Grafana is provisioned with two data sources: Prometheus and Loki. Change provisioning files in `helm/observability/templates/grafana-datasources-configmap.yaml` if needed.
- For production, change the Grafana admin password, enable Loki persistence, and set resource requests and limits for the observability components.
- If you use the operator path, keep an eye on CRDs and RBAC for `ServiceMonitor` and `Probe` resources.

Example production-oriented values:
```yaml
useKubePrometheusStack: true

loki:
  persistence:
    enabled: true
    size: 10Gi

grafana:
  adminPassword: change-me
```
