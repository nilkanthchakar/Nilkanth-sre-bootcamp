# ArgoCD Quickstart

This repo includes ArgoCD Application manifests in `argocd/`.

## Install ArgoCD

1. Create the ArgoCD namespace:

```sh
kubectl create namespace argocd
```

2. Install ArgoCD CRDs and controller:

```sh
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

3. Confirm ArgoCD resources are ready:

```sh
kubectl get pods -n argocd
kubectl get crd applications.argoproj.io
```

## Deploy the student-api app

The required ArgoCD Application manifest is:

- `argocd/student-api-application.yaml`

Apply it after ArgoCD is installed:

```sh
kubectl apply -f argocd/student-api-application.yaml -n argocd
```

Then verify:

```sh
kubectl get applications -n argocd
kubectl describe application student-api -n argocd
```

## Optional: Helm-based ArgoCD app

If you want to deploy the Vault-backed Helm chart instead, use:

```sh
kubectl apply -f argocd/student-api-vault-helm-application.yaml -n argocd
```

## Access ArgoCD UI

Forward the ArgoCD server locally:

```sh
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open:

```
https://localhost:8080
```

The initial admin password is stored in the secret `argocd-initial-admin-secret`:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

## Troubleshooting

If `argocd-applicationset-controller` is CrashLoopBackOff, the ApplicationSet CRD may not be installed. Install it with:

```sh
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/applicationset-install.yaml
kubectl rollout restart deployment/argocd-applicationset-controller -n argocd
```

If you do not need ApplicationSet support, you can still use the ArgoCD UI and the `Application` CRD without the ApplicationSet controller.
