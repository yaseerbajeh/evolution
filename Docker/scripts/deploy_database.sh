#!/bin/bash

source ./Docker/scripts/env_functions.sh

if [ "$DOCKER_ENV" != "true" ]; then
    export_env_vars
fi

# Debug: Print environment variables
echo "=== Environment Debug ==="
echo "DATABASE_PROVIDER: '${DATABASE_PROVIDER}'"
echo "DATABASE_PROVIDER length: ${#DATABASE_PROVIDER}"
if [ -n "$DATABASE_CONNECTION_URI" ]; then
    echo "DATABASE_CONNECTION_URI: ${DATABASE_CONNECTION_URI:0:50}..."
else
    echo "DATABASE_CONNECTION_URI: (not set)"
fi
echo "DOCKER_ENV: ${DOCKER_ENV}"
echo "========================"

# Set default if not set
if [ -z "$DATABASE_PROVIDER" ]; then
    echo "WARNING: DATABASE_PROVIDER is not set, defaulting to 'postgresql'"
    DATABASE_PROVIDER="postgresql"
fi

# Trim whitespace from DATABASE_PROVIDER and convert to lowercase
DATABASE_PROVIDER=$(echo "$DATABASE_PROVIDER" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

if [[ "$DATABASE_PROVIDER" == "postgresql" || "$DATABASE_PROVIDER" == "mysql" || "$DATABASE_PROVIDER" == "psql_bouncer" ]]; then
    # Map DATABASE_CONNECTION_URI to DATABASE_URL for Prisma compatibility
    if [ -z "$DATABASE_URL" ] && [ -n "$DATABASE_CONNECTION_URI" ]; then
        export DATABASE_URL="$DATABASE_CONNECTION_URI"
    fi
    echo "Deploying migrations for $DATABASE_PROVIDER"
    echo "Database URL: ${DATABASE_URL:-$DATABASE_CONNECTION_URI}"
    # rm -rf ./prisma/migrations
    # cp -r ./prisma/$DATABASE_PROVIDER-migrations ./prisma/migrations
    npm run db:deploy
    if [ $? -ne 0 ]; then
        echo "Migration failed"
        exit 1
    else
        echo "Migration succeeded"
    fi
    npm run db:generate
    if [ $? -ne 0 ]; then
        echo "Prisma generate failed"
        exit 1
    else
        echo "Prisma generate succeeded"
    fi
else
    echo "ERROR: Database provider invalid or not set!"
    echo "DATABASE_PROVIDER value: '${DATABASE_PROVIDER}'"
    echo "Expected values: 'postgresql', 'mysql', or 'psql_bouncer'"
    echo ""
    echo "Please set DATABASE_PROVIDER environment variable in Railway:"
    echo "1. Go to your Railway service"
    echo "2. Click on 'Variables' tab"
    echo "3. Add variable: DATABASE_PROVIDER=postgresql"
    echo ""
    echo "Note: Make sure to set it at the SERVICE level, not just as shared variables."
    exit 1
fi
