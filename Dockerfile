# syntax=docker/dockerfile:1

# Build stage: compile the Java application with Maven.
FROM maven:3.9.8-eclipse-temurin-17 AS builder
WORKDIR /workspace

# Copy Maven metadata first so dependencies can be cached.
COPY pom.xml .

# Copy the application source code.
COPY src ./src

# Package the application without running tests.
RUN mvn -B -DskipTests package

# Runtime stage: use a lightweight Java image to run the app.
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Expected artifact name produced by the Maven build.
ARG JAR_FILE=target/student-api-0.1.0.jar

# Create a dedicated non-root user for the runtime container.
RUN groupadd --system app && useradd --system --gid app --create-home --home-dir /home/appuser appuser

# Copy the built JAR from the builder stage into the runtime image.
COPY --from=builder --chown=appuser:app /workspace/${JAR_FILE} /app/app.jar

# Copy the startup script, make it executable, and ensure it is owned by the non-root user.
COPY --chown=appuser:app entrypoint.sh /entrypoint.sh
RUN chmod 550 /entrypoint.sh && chown appuser:app /app

USER appuser

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]