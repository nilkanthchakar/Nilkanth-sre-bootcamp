# syntax=docker/dockerfile:1

FROM maven:3.9.8-eclipse-temurin-17 AS builder
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
RUN mvn -B -DskipTests package

FROM gcr.io/distroless/java17-debian11
WORKDIR /app
ARG JAR_FILE=target/student-api-0.1.0.jar
COPY --from=builder /workspace/${JAR_FILE} /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
