# Helm-based Vault deployment

This guide documents the Helm-based deployment flow for the Vault-backed secret management setup used by the Student API.

## Overview

The Helm chart in `helm/student-api-vault` installs the following resources together:

- Vault server and service
- Kubernetes auth RBAC and Vault policy setup
- bootstrap jobs for Vault auth configuration and DB credential seeding
- the Student API deployment with a Vault Agent sidecar
- the migration ConfigMap used by the database bootstrap flow

The legacy static manifests under `k8s-manifest/` are still kept for reference and rollback purposes.

## Prerequisites

- A working Kubernetes cluster
- `kubectl` configured to the target cluster
- `helm` installed locally
- nodes labeled for the existing workload placement model if required by your cluster

## Install

From the repository root, run:

```bash
helm upgrade --install student-api-vault ./helm/student-api-vault
```

This creates the namespaces, deploys Vault, configures Kubernetes auth, seeds the DB credentials into Vault, and deploys the Student API.

## ArgoCD deployment

The repository also includes ArgoCD Application manifests for single-application deployment.

- `argocd/student-api-vault-helm-application.yaml` deploys the Helm chart from `helm/student-api-vault`.
- `argocd/student-api-vault-application.yaml` deploys the existing manifest-based flow from `k8s-manifest/`.

Apply the Helm-based ArgoCD app into the ArgoCD control plane namespace:

```bash
kubectl apply -f argocd/student-api-vault-helm-application.yaml -n argocd
```

ArgoCD will sync and create namespaces automatically when `CreateNamespace=true` is enabled.

## Observability (optional)

This repository includes an observability Helm chart at `helm/observability`. You can manage it via Argo CD similar to the Vault chart. See `docs/OBSERVABILITY-DEPLOYMENT.md` and `docs/ARGOCD-SETUP.md` for details on installing the operator, applying the Argo CD Application, and configuring ServiceMonitors/Probes.

## Verify the deployment

Check that the resources came up successfully:

```bash
kubectl get pods -n vault
kubectl get pods -n student-api
kubectl get jobs -n vault
```

Inspect the Vault Agent-generated credentials file from the application pod:

```bash
POD=$(kubectl get pods -n student-api -l app=student-api -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n student-api "$POD" -c vault-agent -- cat /vault/secrets/creds.env
```

## Uninstall

To remove the Helm release:

```bash
helm uninstall student-api-vault
```

## Notes

- The chart is intended to be additive. It does not replace the original manifest-based workflow until you are ready to switch.
- The Vault secret path and bootstrap values can be customized through the chart values file in `helm/student-api-vault/values.yaml`.
- The chart uses the same Vault secret layout expected by the app entrypoint and the existing migration flow.
