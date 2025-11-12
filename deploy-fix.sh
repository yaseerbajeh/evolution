#!/bin/bash

# Complete deployment fix script for Evolution API on Hostinger VPS

set -e

echo "=== Evolution API Deployment Fix ==="
echo ""

# Navigate to project directory
cd ~/evolution || { echo "Error: evolution directory not found"; exit 1; }

echo "Step 1: Fixing .env file..."
# Remove BOM and fix line endings
sed -i '1s/^\xEF\xBB\xBF//' .env 2>/dev/null || true
sed -i 's/\r$//' .env
sed -i '/./,$!d' .env

# Remove duplicate N8N_ENABLED
if [ $(grep -c "^N8N_ENABLED=" .env) -gt 1 ]; then
    echo "Removing duplicate N8N_ENABLED entries..."
    sed -i '/^N8N_ENABLED=false$/d' .env
    if ! grep -q "^N8N_ENABLED=true$" .env; then
        sed -i '/^# N8N$/a N8N_ENABLED=true' .env
    fi
fi

# Update SERVER_URL if needed
if grep -q "SERVER_URL=http://localhost:8080" .env; then
    echo "Updating SERVER_URL to VPS IP..."
    sed -i 's|SERVER_URL=http://localhost:8080|SERVER_URL=http://72.60.92.80:8080|g' .env
fi

# Clean up .env file
sed -i 's/ = /=/g' .env
sed -i 's/[[:space:]]*$//' .env

echo "Step 2: Verifying .env file..."
if ! grep -q "^DATABASE_CONNECTION_URI=" .env; then
    echo "ERROR: DATABASE_CONNECTION_URI not found!"
    exit 1
fi

echo "Step 3: Restarting container..."
docker-compose down
docker-compose up -d --build

echo "Step 4: Waiting for container to start..."
sleep 10

echo "Step 5: Checking container status..."
docker-compose ps

echo "Step 6: Checking logs..."
echo "=== Recent logs ==="
docker-compose logs --tail=30 api

echo ""
echo "=== Fix complete ==="
echo "Check logs with: docker-compose logs -f api"
echo "Test API with: curl http://localhost:8080"

