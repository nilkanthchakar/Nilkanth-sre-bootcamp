# Student Management REST API

A Spring Boot CRUD REST API for managing student records.

## Features

- Add a new student
- Get all students
- Get a student by ID
- Update student data
- Delete a student record
- API versioning (`/api/v1/...`)
- Healthcheck endpoint (`/api/v1/health` and `/actuator/health`)
- Flyway migrations for database schema
- Environment-based database configuration

## Prerequisites

- Java 17 or newer
- Maven
- Docker (optional, for PostgreSQL)

## Local setup

1. Copy `.env.example` to `.env` and update values as needed.

2. Start the API and PostgreSQL together using Docker Compose:

```sh
make compose-up
```

3. When you are done, stop the stack:

```sh
make compose-down
```

4. If you need to rebuild after code changes:

```sh
make compose-build
```

## Environment variables

- `SPRING_DATASOURCE_URL`
- `SPRING_DATASOURCE_USERNAME`
- `SPRING_DATASOURCE_PASSWORD`
- `SERVER_PORT`

## Build and test

```sh
make build
make test
make lint
```

## Docker

Build the Docker image:

```sh
make docker-build
```

Run the application using Docker Compose:

```sh
make compose-up
```

Stop the Compose stack:

```sh
make compose-down
```

If you want to run the API container directly:

```sh
docker run --rm -p 8080:8080 --env-file .env student-api:0.1.0
```

## Vagrant deployment

The production-like deployment uses Vagrant with Docker Compose and Nginx load balancing.

Start the Vagrant box:

```sh
make vagrant-up
```

Provision the box and deploy services:

```sh
make vagrant-provision
```

Access the API at:

```sh
http://localhost:8080/api/v1/students
```

Stop the Vagrant box:

```sh
make vagrant-halt
```

Destroy the Vagrant box:

```sh
make vagrant-destroy
```

## CI Pipeline

The repository includes a GitHub Actions workflow that runs on a self-hosted runner.

The pipeline stages are:

- Build API (`make build`)
- Run tests (`make test`)
- Perform code linting (`make lint`)
- Docker Hub login and push

The workflow triggers on changes to source code and build files only, including:

- `src/**`
- `pom.xml`
- `Dockerfile`
- `Makefile`

It also supports manual dispatch from the GitHub Actions UI.

### Docker Hub secrets

Set the following repository secrets before running the workflow:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## API Endpoints

- `GET /api/v1/students`
- `GET /api/v1/students/{id}`
- `POST /api/v1/students`
- `PUT /api/v1/students/{id}`
- `DELETE /api/v1/students/{id}`
- `GET /api/v1/health`
- `GET /actuator/health`

## Student payload

```json
{
  "firstName": "Jane",
  "lastName": "Doe",
  "email": "jane.doe@example.com"
}
```

## Postman Collection

Import `postman/student-api.postman_collection.json` into Postman.
