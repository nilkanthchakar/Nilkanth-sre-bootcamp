# Student Management REST API

A Spring Boot CRUD REST API for managing student records, with local Docker support, Kubernetes deployment, Vault-backed secrets, and Argo CD examples.

## What this repo supports

After cloning the repository, you can:

- run the app locally with Maven
- run the app and PostgreSQL with Docker Compose
- build and test the Java service
- deploy the app to a local Kubernetes cluster
- install Vault and bootstrap secrets with Helm
- apply Argo CD manifests for GitOps-style deployment

## Prerequisites

Install these tools before starting:

- Java 17+
- Maven
- Docker Desktop or Docker Engine
- Docker Compose
- kubectl
- Helm
- Minikube (optional, for local Kubernetes)
- Vagrant (optional, for the VM-based deployment)

## 1. Clone and prepare the environment

```bash
git clone <your-repo-url>
cd Nilkanth-sre-bootcamp
make setup-env
```

This creates a local `.env` file from `.env.example`. Review it and adjust values if needed.

## 2. Run locally with Maven

```bash
make build
make run
```

The service will start on port `8080` by default.

## 3. Run locally with Docker Compose

```bash
make compose-up
```

This starts the Spring Boot app and PostgreSQL together. When you are done:

```bash
make compose-down
```

## 4. Build, test, and lint

```bash
make build
make test
make lint
```

## 5. Build the container image

```bash
make docker-build
```

## 6. Deploy to Kubernetes with Vault and Helm

If you are using Minikube or any local Kubernetes cluster, start it first:

```bash
make minikube-start
make minikube-add-labels
```

Then install the Helm release:

```bash
make vault-helm-install
```

Verify the deployment:

```bash
make kubectl-verify
```

To remove the Helm release:

```bash
make vault-helm-uninstall
```

## 7. Argo CD deployment

Install Argo CD into the cluster:

```bash
make argocd-install
make argocd-wait
```

Apply the example Argo CD applications:

```bash
make argocd-apply-app
```

Open the UI locally:

```bash
make argocd-port-forward
```

Then open https://localhost:8080 and sign in using the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

## 8. Static manifest deployment (alternative)

If you want the older manifest-based workflow instead of Helm, run:

```bash
make kubectl-apply-manifests
```

## 9. Vagrant deployment (optional)

```bash
make vagrant-up
make vagrant-provision
```

Stop or destroy it with:

```bash
make vagrant-halt
make vagrant-destroy
```

## Environment variables

The application reads these values from `.env`:

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `SERVER_PORT`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

## API endpoints

- `GET /api/v1/students`
- `GET /api/v1/students/{id}`
- `POST /api/v1/students`
- `PUT /api/v1/students/{id}`
- `DELETE /api/v1/students/{id}`
- `GET /api/v1/health`
- `GET /actuator/health`

## Example payload

```json
{
  "firstName": "Jane",
  "lastName": "Doe",
  "email": "jane.doe@example.com"
}
```

## Postman collection

Import [postman/student-api.postman_collection.json](postman/student-api.postman_collection.json) into Postman.

## Observability stack (Prometheus, Loki, Grafana)

This repository includes a Helm chart for a lightweight observability stack at `helm/observability`.
For the full install, operator, Argo CD, and validation flow, see [docs/OBSERVABILITY-DEPLOYMENT.md](docs/OBSERVABILITY-DEPLOYMENT.md).

Quick setup (assumes kubectl and helm are configured for your cluster):

1. Label the node you want to host the dependent services (the "dependent_services" node):

```bash
kubectl label node <node-name> dependent_services=true
```

2. Install the chart:

```bash
helm upgrade --install observability ./helm/observability -n observability --create-namespace
```

3. Notes and configuration:
- Promtail is configured to only collect logs from the `student-api` namespace by default. Adjust `applicationNamespace` in `helm/observability/values.yaml` if your application namespace differs.
- The Postgres exporter uses a `DATA_SOURCE_NAME` environment value in the chart; you should replace the placeholder credentials with a Kubernetes `Secret` and patch `templates/postgres-exporter-deployment.yaml` to mount them as environment variables.
- Prometheus scrapes the app, node-exporter, kube-state-metrics, Postgres exporter, and blackbox-exporter by default. The blackbox job probes the student API health endpoint unless you change `blackbox.targets` in `helm/observability/values.yaml`.
- Grafana is provisioned with Prometheus and Loki data sources, and the chart includes dashboards and alert rules for node, DB, kube-state, blackbox, application logs, latency, error rate, and restart events.

4. Verifying:

```bash
kubectl get pods -n observability
kubectl port-forward svc/grafana -n observability 3000:3000
# open http://localhost:3000 (admin/admin)
```

If you want help wiring secrets for the Postgres exporter or customizing scrape configs, tell me which cluster environment you use and I can update the chart to reference an existing secret.

### Using kube-prometheus-stack (Prometheus Operator)

If you prefer the Prometheus Operator (`kube-prometheus-stack`) instead of the chart's built-in Prometheus and exporters, do the following:

1. Install the `kube-prometheus-stack` from `prometheus-community` (example):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n observability --create-namespace
```

2. Disable the chart's built-in Prometheus/exporters to avoid conflicts by setting the flag when installing or upgrading this chart:

```bash
helm upgrade --install observability ./helm/observability -n observability --set useKubePrometheusStack=true
```

3. If you want GitOps via Argo CD, add or update this Application manifest in `argocd/observability-helm-application.yaml` and apply it to the Argo CD control plane:

```bash
kubectl apply -f argocd/observability-helm-application.yaml -n argocd
```

4. The chart creates the `ServiceMonitor`, `Probe`, and `PrometheusRule` resources needed by `kube-prometheus-stack` to scrape `student-api`, Postgres exporter, and the blackbox targets.
