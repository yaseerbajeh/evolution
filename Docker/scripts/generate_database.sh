#!/bin/bash

source ./Docker/scripts/env_functions.sh

if [ "$DOCKER_ENV" != "true" ]; then
    export_env_vars
fi

if [[ "$DATABASE_PROVIDER" == "postgresql" || "$DATABASE_PROVIDER" == "mysql" || "$DATABASE_PROVIDER" == "psql_bouncer" ]]; then
    # Map DATABASE_CONNECTION_URI to DATABASE_URL for Prisma compatibility
    if [ -z "$DATABASE_URL" ] && [ -n "$DATABASE_CONNECTION_URI" ]; then
        export DATABASE_URL="$DATABASE_CONNECTION_URI"
    fi
    echo "Generating database for $DATABASE_PROVIDER"
    echo "Database URL: ${DATABASE_URL:-$DATABASE_CONNECTION_URI}"
    npm run db:generate
    if [ $? -ne 0 ]; then
        echo "Prisma generate failed"
        exit 1
    else
        echo "Prisma generate succeeded"
    fi
else
    echo "Error: Database provider $DATABASE_PROVIDER invalid."
    exit 1
fi