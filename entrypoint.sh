#!/bin/sh
set -e

# Wait until Vault has provided the credentials file before starting the app.
if [ ! -f /vault/secrets/creds.env ]; then
  echo "Waiting for Vault credentials..."
  while [ ! -f /vault/secrets/creds.env ]; do
    sleep 1
  done
fi

# Make the rendered file readable for the non-root runtime user.
chmod 666 /vault/secrets/creds.env 2>/dev/null || true

# Load the credentials into the environment for the Java process.
set -a
. /vault/secrets/creds.env
set +a

# Start the Spring Boot application.
exec java -jar /app/app.jar
