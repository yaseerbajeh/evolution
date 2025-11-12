#!/bin/bash
set -e

cd ~/evolution

echo "=== Step 1: Fixing docker-compose.yaml ==="
cp docker-compose.production.yaml docker-compose.yaml
rm -f docker-compose.override.yaml
echo "✅ docker-compose.yaml fixed"

echo ""
echo "=== Step 2: Fixing .env file ==="
if [ ! -f .env ]; then
    echo "❌ .env file not found!"
    exit 1
fi

# Fix .env issues
sed -i '1s/^\xEF\xBB\xBF//' .env 2>/dev/null || true
sed -i 's/\r$//' .env
sed -i '/./,$!d' .env
sed -i 's|SERVER_URL=.*|SERVER_URL=http://72.60.92.80:8080|g' .env
sed -i '/^N8N_ENABLED=false$/d' .env
if ! grep -q "^N8N_ENABLED=true$" .env; then
    echo "N8N_ENABLED=true" >> .env
fi
sed -i 's/ = /=/g' .env
sed -i 's/[[:space:]]*$//' .env
echo "✅ .env file fixed"

echo ""
echo "=== Step 3: Creating override to skip migrations ==="
cat > docker-compose.override.yaml << 'EOF'
version: "3.8"
services:
  api:
    entrypoint: ["/bin/sh", "-c"]
    command: |
      cd /evolution
      export DATABASE_PROVIDER=postgresql
      export DATABASE_URL=$$DATABASE_CONNECTION_URI
      npm run db:generate
      npm run start:prod
EOF
echo "✅ Override created"

echo ""
echo "=== Step 4: Stopping containers ==="
docker-compose down || true

echo ""
echo "=== Step 5: Building and starting ==="
docker-compose up -d --build

echo ""
echo "=== Step 6: Waiting 20 seconds ==="
sleep 20

echo ""
echo "=== Step 7: Status ==="
docker-compose ps

echo ""
echo "=== Step 8: Logs ==="
docker-compose logs --tail=30 api

