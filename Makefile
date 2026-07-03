# Makefile for Student Management REST API

IMAGE_NAME=student-api
IMAGE_VERSION=0.1.0
IMAGE_TAG=${IMAGE_NAME}:${IMAGE_VERSION}

.PHONY: build run migrate test docker-build compose-build compose-up compose-down clean

build:
	mvn -B clean package

run:
	@echo "Loading environment variables from .env"
	@set -a && source .env && set +a && mvn spring-boot:run

migrate:
	@echo "Applying Flyway migrations"
	@set -a && source .env && set +a && mvn flyway:migrate

docker-build:
	@echo "Building Docker image ${IMAGE_TAG}"
	docker build --build-arg JAR_FILE=target/${IMAGE_NAME}-${IMAGE_VERSION}.jar -t ${IMAGE_TAG} .

compose-build:
	@echo "Building Docker Compose services"
	docker compose build

compose-up:
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

minikube-add-labels:
	@echo "Adding labels to Minikube nodes"
	kubectl label node minikube-m02 type=application
	kubectl label node minikube-m03 type=database
	kubectl label node minikube-m04 type=dependent_services

minikube-stop:
	@echo "Stopping Minikube cluster"
	minikube stop

minikube-delete:
	@echo "Deleting Minikube cluster"
	minikube delete	