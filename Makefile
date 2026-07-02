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

test:
	mvn -B test

clean:
	mvn -B clean
