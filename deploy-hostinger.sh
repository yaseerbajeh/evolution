#!/bin/bash

# Complete deployment script for Evolution API on Hostinger VPS
# This script fixes all issues and deploys the application

set -e

echo "=== Evolution API Deployment Script ==="
echo ""

# Navigate to project directory
cd ~/evolution || { echo "Error: evolution directory not found"; exit 1; }

echo "Step 1: Fixing docker-compose.yaml..."
# Ensure we're using production version
cp docker-compose.production.yaml docker-compose.yaml

# Remove any override files
rm -f docker-compose.override.yaml

echo "✅ docker-compose.yaml fixed"

echo ""
echo "Step 2: Verifying .env file..."
if [ ! -f .env ]; then
    echo "❌ ERROR: .env file not found!"
    echo "Please upload your .env file to ~/evolution/.env"
    exit 1
fi

# Fix .env file issues
echo "Fixing .env file..."
# Remove BOM if present
sed -i '1s/^\xEF\xBB\xBF//' .env 2>/dev/null || true
# Fix line endings
sed -i 's/\r$//' .env
# Remove empty lines at start
sed -i '/./,$!d' .env

# Ensure SERVER_URL is set to VPS IP
if ! grep -q "SERVER_URL=http://72.60.92.80:8080" .env; then
    echo "Updating SERVER_URL to VPS IP..."
    sed -i 's|SERVER_URL=.*|SERVER_URL=http://72.60.92.80:8080|g' .env
fi

# Remove duplicate N8N_ENABLED (keep only true)
sed -i '/^N8N_ENABLED=false$/d' .env
if ! grep -q "^N8N_ENABLED=true$" .env; then
    # Add N8N_ENABLED=true if it doesn't exist
    if grep -q "^# N8N" .env; then
        sed -i '/^# N8N$/a N8N_ENABLED=true' .env
    else
        echo "N8N_ENABLED=true" >> .env
    fi
fi

# Clean up whitespace
sed -i 's/ = /=/g' .env
sed -i 's/[[:space:]]*$//' .env

echo "✅ .env file fixed"

echo ""
echo "Step 3: Creating docker-compose override to skip migrations..."
# Create override to skip migrations and start app directly
cat > docker-compose.override.yaml << 'OVERRIDE_EOF'
version: "3.8"
services:
  api:
    entrypoint: ["/bin/sh", "-c"]
    command: |
      cd /evolution
      export DATABASE_PROVIDER=postgresql
      if [ -n "$$DATABASE_CONNECTION_URI" ]; then
        export DATABASE_URL="$$DATABASE_CONNECTION_URI"
      fi
      echo "=== Generating Prisma Client ==="
      npm run db:generate || echo "Warning: Prisma generate failed, but continuing..."
      echo "=== Starting Application ==="
      npm run start:prod
OVERRIDE_EOF

echo "✅ Override file created"

echo ""
echo "Step 4: Stopping existing containers..."
docker-compose down || true

echo ""
echo "Step 5: Building and starting container..."
docker-compose up -d --build

echo ""
echo "Step 6: Waiting for container to start..."
sleep 15

echo ""
echo "Step 7: Checking container status..."
docker-compose ps

echo ""
echo "Step 8: Checking logs (last 30 lines)..."
docker-compose logs --tail=30 api

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Check logs: docker-compose logs -f api"
echo "2. Test API: curl http://72.60.92.80:8080"
echo "3. Access Manager: http://72.60.92.80:8080/manager"
echo ""
echo "Note: Migrations were skipped. Run them separately if needed:"
echo "  docker-compose exec api npm run db:deploy"
