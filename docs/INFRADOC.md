**Overview**

This document describes the production-like Kubernetes deployment and Vault-backed secret management for the Student API service. It covers architecture, manifests, deployment steps, verification, security hardening, backups, rollback, and the newer Helm-based deployment path.

**Architecture**

- Namespace layout:
  - `vault`: Vault server and supporting components
  - `student-api`: application, Postgres, Vault Agent sidecars
- Vault: HashiCorp Vault (KV v2) running in `vault` namespace. Kubernetes Auth is used for workloads to authenticate.
- Secret flow:
  - DB credentials are stored in Vault at `secret/data/student-api/db-credentials` (KV v2)
  - Workloads use Vault Agent (sidecar) to authenticate via Kubernetes auth and render `/vault/secrets/creds.env`
  - Application sources `/vault/secrets/creds.env` on startup
- Migrations:
  - A dedicated `Job` (`student-db-migrate`) runs migrations. The Job contains a `vault-agent` sidecar and a `migrate` container (Postgres client) that sources the rendered creds and applies SQL from a `ConfigMap`.

**Deployment options**

- Manifest-based deployment remains available under `k8s-manifest/` for reference and rollback.
- Helm-based deployment is available through `helm/student-api-vault` and is documented in `docs/HELM-VAULT-DEPLOYMENT.md`.

**Key Manifests (location: `k8s-manifest/`)**

- `student-api-vault.yaml` - Deployment for Student API with `vault-agent` sidecar and `student-api-sa` ServiceAccount.
- `postgres-deployment.yaml` - Postgres Deployment, Service, and PVCs.
- `db-migrations-configmap.yaml` - ConfigMap with SQL migration files.
- `db-migrate-job.yaml` - Job that runs DB migrations using Vault Agent and Postgres client.
- `vault-deployment.yaml` - Vault server Deployment (runs in `vault` namespace).
- `vault-configmap.yaml` - Vault Agent configuration (templates & auto_auth).
- `vault-seed-job.yaml` - Job to seed DB credentials into Vault (used once during setup).
- `vault-enable-k8s-auth-fixed.yaml` - Job to enable Kubernetes auth, policy and role mappings in Vault.

**Deployment Steps**

For the Helm-based flow, use:

```bash
helm upgrade --install student-api-vault ./helm/student-api-vault
```

For the original manifest-based flow, continue with the steps below.

1. Ensure cluster readiness and nodes have label `type=application` for scheduling application pods.

2. Deploy Vault in the `vault` namespace (ensure it's not in dev-mode for production):

```bash
kubectl apply -f k8s-manifest/namespaces.yaml
kubectl apply -f k8s-manifest/vault-deployment.yaml
kubectl apply -f k8s-manifest/vault-configmap.yaml -n vault
```

3. Enable Kubernetes auth in Vault and write policy/role (runs in `vault` namespace):

```bash
kubectl apply -f k8s-manifest/vault-auth-sa.yaml
kubectl apply -f k8s-manifest/vault-enable-k8s-auth-fixed.yaml -n vault
```

4. Seed DB credentials into Vault (one-time):

```bash
kubectl apply -f k8s-manifest/vault-seed-job.yaml -n vault
kubectl wait --for=condition=complete job/vault-seed-job -n vault --timeout=60s
```

5. Deploy Postgres and create migration ConfigMap:

```bash
kubectl apply -f k8s-manifest/db-migrations-configmap.yaml -n student-api
kubectl apply -f k8s-manifest/postgres-deployment.yaml -n student-api
```

6. Run the migration Job (authenticated via Vault Agent):

```bash
kubectl apply -f k8s-manifest/db-migrate-job.yaml -n student-api
kubectl wait --for=condition=complete job/student-db-migrate -n student-api --timeout=120s
kubectl logs job/student-db-migrate -n student-api --tail=200
```

7. Deploy the application (it reads creds from Vault Agent sidecar):

```bash
kubectl apply -f k8s-manifest/student-api-vault.yaml -n student-api
kubectl rollout status deployment/student-api -n student-api
```

**Verification**

- Vault Agent logs show successful authentication and template rendering:
  - `agent.auth.handler: authentication successful`
  - `agent.template.server: rendered "(dynamic)" => "/vault/secrets/creds.env"`
- Migration job logs show successful psql execution and table creation.
- Application pod logs show successful DB connection and Tomcat startup.
- Inspect `/vault/secrets/creds.env` in any pod with `vault-agent` to verify values.

**Security & Hardening**

- DO NOT run Vault in dev-mode for production; configure storage backends and auto-unseal (KMS or HSM).
- Restrict Vault policies to minimal required paths; each app should have a narrow policy.
- Use short TTLs for tokens where appropriate and rotate credentials regularly.
- Limit ServiceAccount permissions; only `vault-auth` needs `system:auth-delegator` and a dedicated token-reviewer SA.
- Consider using NetworkPolicies to limit network access to Vault/DB from only trusted namespaces.
- Enable auditing in Vault and persist logs.

**Backup & Recovery**

- Backup Vault storage backend (consistently) and test restore procedures regularly.
- Backup Postgres persistent volumes and use point-in-time recovery where required.

**Rollbacks**

- To rollback migrations: keep SQL reverse scripts or DB backups. Rolling back schema changes may require manual steps.
- For app rollbacks, use `kubectl rollout undo deployment/student-api`.

**Operational notes**

- CI/CD should run a preview of migrations against a staging DB and produce migration artifacts.
- The Helm chart is additive and can be used in parallel with the existing manifests while you migrate gradually.
- Consider using an operator (e.g., `vault-helm` + `vault-operator`) and `ExternalSecrets` if you prefer Kubernetes-native secret sync.

**Next actions**

- Replace any remaining Kubernetes Secrets containing DB credentials (like `student-db-credentials`) after verifying the migration job and application work correctly with Vault-only creds.
- Harden Vault with auto-unseal and persistent storage.

