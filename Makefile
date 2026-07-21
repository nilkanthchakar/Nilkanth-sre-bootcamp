# Makefile for Student Management REST API

IMAGE_NAME ?= student-api
IMAGE_VERSION ?= 0.1.0
IMAGE_TAG ?= $(IMAGE_NAME):$(IMAGE_VERSION)

KUBECTL ?= kubectl
HELM ?= helm
ARGOCD_NAMESPACE ?= argocd
OBSERVABILITY_NAMESPACE ?= observability
VAULT_NAMESPACE ?= vault
STUDENT_API_NAMESPACE ?= student-api
VAULT_RELEASE ?= student-api-vault
VAULT_SERVICE_ACCOUNT ?= vault-auth
STUDENT_API_SERVICE_ACCOUNT ?= student-api-sa
KUBE_PROMETHEUS_RELEASE ?= kube-prometheus-stack

.PHONY: help build run migrate test docker-build compose-build compose-up compose-down clean lint setup-env vagrant-up vagrant-provision vagrant-halt vagrant-destroy deploy-vagrant minikube-start minikube-image-build minikube-add-labels minikube-stop minikube-delete argocd-install argocd-wait argocd-port-forward argocd-apply-app argocd-apply-legacy-vault-app argocd-delete-app kube-prometheus-install cluster-deploy vault-helm-install vault-helm-uninstall kubectl-apply-manifests kubectl-verify

help:
	@echo "Available targets:"
	@echo "  make setup-env            Create .env from .env.example"
	@echo "  make build                Build the Java app"
	@echo "  make test                 Run tests"
	@echo "  make lint                 Run checkstyle"
	@echo "  make run                  Run the Spring Boot app locally"
	@echo "  make migrate              Run Flyway migrations"
	@echo "  make compose-up           Start the local Docker Compose stack"
	@echo "  make compose-down         Stop the local Docker Compose stack"
	@echo "  make docker-build         Build the Docker image"
	@echo "  make minikube-start       Start a local Kubernetes cluster"
	@echo "  make minikube-image-build Build the API image on every Minikube node"
	@echo "  make argocd-install       Install Argo CD into the cluster"
	@echo "  make argocd-apply-app     Apply the Argo CD application manifests"
	@echo "  make cluster-deploy       Start Minikube, install Argo CD/monitoring, and deploy the API"
	@echo "  make vault-helm-install   Install Vault and the app via Helm"
	@echo "  make kubectl-apply-manifests Apply the static Kubernetes manifests"
	@echo "  make vagrant-up           Start the Vagrant deployment"

setup-env:
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example"; \
		cp .env.example .env; \
	else \
		echo ".env already exists"; \
	fi

build:
	mvn -B clean package

run: setup-env
	@echo "Loading environment variables from .env"
	@set -a && source .env && set +a && mvn spring-boot:run

migrate: setup-env
	@echo "Applying Flyway migrations"
	@set -a && source .env && set +a && mvn flyway:migrate

docker-build:
	@echo "Building Docker image $(IMAGE_TAG)"
	docker build --build-arg JAR_FILE=target/$(IMAGE_NAME)-$(IMAGE_VERSION).jar -t $(IMAGE_TAG) .

compose-build:
	@echo "Building Docker Compose services"
	docker compose build

compose-up: setup-env
	@echo "Starting services with Docker Compose"
	docker compose up --build

compose-down:
	@echo "Stopping services and removing volumes"
	docker compose down -v

vagrant-up:
	@echo "Starting Vagrant production environment"
	vagrant up

vagrant-provision:
	@echo "Provisioning Vagrant box and deploying stack"
	vagrant provision

vagrant-halt:
	@echo "Stopping Vagrant environment"
	vagrant halt

vagrant-destroy:
	@echo "Destroying Vagrant environment"
	vagrant destroy -f

deploy-vagrant:
	@echo "Deploying services inside Vagrant"
	cd /vagrant && docker compose -f docker-compose.vagrant.yml up -d

lint:
	mvn -B checkstyle:check

test:
	mvn -B test

clean:
	mvn -B clean

minikube-start:
	@echo "Starting Minikube cluster"
	minikube start --driver=docker --nodes=4

minikube-image-build:
	@echo "Building $(IMAGE_TAG) on every Minikube node"
	minikube image build --all -t $(IMAGE_TAG) .

minikube-add-labels:
	@echo "Adding labels to Minikube nodes"
	kubectl label node minikube-m02 type=application --overwrite
	kubectl label node minikube-m03 type=database --overwrite
	kubectl label node minikube-m04 type=dependent_services dependent_services=true --overwrite

minikube-stop:
	@echo "Stopping Minikube cluster"
	minikube stop

minikube-delete:
	@echo "Deleting Minikube cluster"
	minikube delete

argocd-install:
	@echo "Installing Argo CD"
	$(KUBECTL) create namespace $(ARGOCD_NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) apply --server-side --force-conflicts -n $(ARGOCD_NAMESPACE) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-wait:
	@echo "Waiting for Argo CD server to be ready"
	$(KUBECTL) wait --for=condition=available deployment/argocd-server -n $(ARGOCD_NAMESPACE) --timeout=600s

argocd-port-forward:
	@echo "Port-forwarding Argo CD UI"
	@echo "Open https://localhost:8080"
	$(KUBECTL) port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) 8080:443

argocd-apply-app:
	@echo "Applying Argo CD applications for the Vault-backed API and observability"
	$(KUBECTL) apply -f argocd/student-api-vault-helm-application.yaml -n $(ARGOCD_NAMESPACE)
	$(KUBECTL) apply -f argocd/observability-helm-application.yaml -n $(ARGOCD_NAMESPACE)

argocd-apply-legacy-vault-app:
	@echo "Applying the legacy static-manifest Vault application"
	$(KUBECTL) apply -f argocd/student-api-vault-application.yaml -n $(ARGOCD_NAMESPACE)

argocd-delete-app:
	@echo "Deleting Argo CD application resources"
	$(KUBECTL) delete -f argocd/student-api-vault-helm-application.yaml -n $(ARGOCD_NAMESPACE) --ignore-not-found
	$(KUBECTL) delete -f argocd/student-api-vault-application.yaml -n $(ARGOCD_NAMESPACE) --ignore-not-found
	$(KUBECTL) delete -f argocd/observability-helm-application.yaml -n $(ARGOCD_NAMESPACE) --ignore-not-found

kube-prometheus-install:
	@echo "Installing kube-prometheus-stack required by the observability Argo CD application"
	$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts
	$(HELM) repo update
	$(HELM) upgrade --install $(KUBE_PROMETHEUS_RELEASE) prometheus-community/kube-prometheus-stack --namespace $(OBSERVABILITY_NAMESPACE) --create-namespace

cluster-deploy: minikube-start minikube-image-build minikube-add-labels argocd-install argocd-wait kube-prometheus-install argocd-apply-app
	@echo "Waiting for Argo CD to synchronize the Vault-backed Student API chart"
	$(KUBECTL) wait --for=jsonpath='{.status.sync.status}'=Synced application/student-api-vault-helm -n $(ARGOCD_NAMESPACE) --timeout=600s
	@echo "Waiting for Student API resources to become ready"
	$(KUBECTL) rollout status deployment/vault -n $(VAULT_NAMESPACE) --timeout=300s
	$(KUBECTL) rollout status deployment/student-db -n $(STUDENT_API_NAMESPACE) --timeout=300s
	$(KUBECTL) rollout status deployment/student-api -n $(STUDENT_API_NAMESPACE) --timeout=300s
	@echo "Cluster deployment complete. Run 'make kubectl-verify' for a status summary."

vault-helm-install:
	@echo "Installing Vault and the student API through Helm"
	@for ns in $(VAULT_NAMESPACE) $(STUDENT_API_NAMESPACE); do \
		$(KUBECTL) get namespace $$ns >/dev/null 2>&1 || $(KUBECTL) create namespace $$ns >/dev/null 2>&1; \
		$(KUBECTL) label namespace $$ns app.kubernetes.io/managed-by=Helm --overwrite >/dev/null 2>&1; \
		$(KUBECTL) annotate namespace $$ns meta.helm.sh/release-name=$(VAULT_RELEASE) meta.helm.sh/release-namespace=$(VAULT_NAMESPACE) --overwrite >/dev/null 2>&1; \
	done; \
	$(KUBECTL) get serviceaccount $(VAULT_SERVICE_ACCOUNT) -n $(VAULT_NAMESPACE) >/dev/null 2>&1 && $(KUBECTL) label serviceaccount $(VAULT_SERVICE_ACCOUNT) -n $(VAULT_NAMESPACE) app.kubernetes.io/managed-by=Helm --overwrite >/dev/null 2>&1 && $(KUBECTL) annotate serviceaccount $(VAULT_SERVICE_ACCOUNT) -n $(VAULT_NAMESPACE) meta.helm.sh/release-name=$(VAULT_RELEASE) meta.helm.sh/release-namespace=$(VAULT_NAMESPACE) --overwrite >/dev/null 2>&1 || true; \
	$(KUBECTL) get serviceaccount $(STUDENT_API_SERVICE_ACCOUNT) -n $(STUDENT_API_NAMESPACE) >/dev/null 2>&1 && $(KUBECTL) label serviceaccount $(STUDENT_API_SERVICE_ACCOUNT) -n $(STUDENT_API_NAMESPACE) app.kubernetes.io/managed-by=Helm --overwrite >/dev/null 2>&1 && $(KUBECTL) annotate serviceaccount $(STUDENT_API_SERVICE_ACCOUNT) -n $(STUDENT_API_NAMESPACE) meta.helm.sh/release-name=$(VAULT_RELEASE) meta.helm.sh/release-namespace=$(VAULT_NAMESPACE) --overwrite >/dev/null 2>&1 || true; \
	$(HELM) uninstall $(VAULT_RELEASE) -n $(VAULT_NAMESPACE) >/dev/null 2>&1 || true; \
	$(HELM) upgrade --install $(VAULT_RELEASE) ./helm/student-api-vault --namespace $(VAULT_NAMESPACE)

vault-helm-uninstall:
	@echo "Uninstalling Vault Helm release"
	$(HELM) uninstall $(VAULT_RELEASE) -n $(VAULT_NAMESPACE) || true

kubectl-apply-manifests:
	@echo "Applying Kubernetes manifests"
	$(KUBECTL) apply -f k8s-manifest/namespaces.yaml
	$(KUBECTL) apply -f k8s-manifest/vault-deployment.yaml
	$(KUBECTL) apply -f k8s-manifest/vault-configmap.yaml -n $(VAULT_NAMESPACE)
	$(KUBECTL) apply -f k8s-manifest/vault-auth-sa.yaml
	$(KUBECTL) apply -f k8s-manifest/vault-enable-k8s-auth-fixed.yaml -n $(VAULT_NAMESPACE)
	$(KUBECTL) apply -f k8s-manifest/vault-seed-job.yaml -n $(VAULT_NAMESPACE)
	$(KUBECTL) apply -f k8s-manifest/db-migrations-configmap.yaml -n $(STUDENT_API_NAMESPACE)
	$(KUBECTL) apply -f k8s-manifest/postgres-deployment.yaml -n $(STUDENT_API_NAMESPACE)
	$(KUBECTL) apply -f k8s-manifest/db-migrate-job.yaml -n $(STUDENT_API_NAMESPACE)
	$(KUBECTL) apply -f k8s-manifest/student-api-vault.yaml -n $(STUDENT_API_NAMESPACE)

kubectl-verify:
	@echo "Checking pod and job status"
	$(KUBECTL) get pods -n $(VAULT_NAMESPACE) || true
	$(KUBECTL) get pods -n $(STUDENT_API_NAMESPACE) || true
	$(KUBECTL) get jobs -n $(VAULT_NAMESPACE) || true
