#!/bin/bash

# Fix .env file issues on server
# This script fixes BOM, line endings, and ensures proper format

cd ~/evolution || exit 1

echo "=== Fixing .env file ==="

# Backup original .env
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo "Backup created"

# Remove BOM if present
sed -i '1s/^\xEF\xBB\xBF//' .env
echo "BOM removed (if present)"

# Convert Windows line endings to Unix
sed -i 's/\r$//' .env
echo "Line endings fixed"

# Remove empty lines at the beginning
sed -i '/./,$!d' .env
echo "Empty lines at start removed"

# Ensure first line is not a comment (move comments after first non-comment line if needed)
# Check if first line is a comment
if head -1 .env | grep -q '^#'; then
    echo "First line is a comment, this might cause parsing issues"
    # We'll keep it but ensure no BOM
fi

# Remove duplicate N8N_ENABLED entries (keep only the last one, or first true)
if grep -c "^N8N_ENABLED" .env | grep -q "^2"; then
    echo "Removing duplicate N8N_ENABLED entries"
    # Remove all N8N_ENABLED lines
    sed -i '/^N8N_ENABLED=/d' .env
    # Add single N8N_ENABLED=true at the end of N8N section
    sed -i '/^# N8N$/a N8N_ENABLED=true' .env || echo "N8N_ENABLED=true" >> .env
fi

# Verify DATABASE_CONNECTION_URI is set
if ! grep -q "^DATABASE_CONNECTION_URI=" .env; then
    echo "ERROR: DATABASE_CONNECTION_URI not found in .env"
    exit 1
fi

# Verify SERVER_URL is set to VPS IP
if grep -q "SERVER_URL=http://localhost" .env; then
    echo "Updating SERVER_URL to VPS IP"
    sed -i 's|SERVER_URL=http://localhost:8080|SERVER_URL=http://72.60.92.80:8080|g' .env
fi

# Ensure no spaces around = sign
sed -i 's/ = /=/g' .env
sed -i 's/= /=/g' .env

# Remove trailing spaces
sed -i 's/[[:space:]]*$//' .env

echo "=== .env file fixed ==="
echo ""
echo "Verification:"
echo "First line: $(head -1 .env)"
echo "DATABASE_CONNECTION_URI: $(grep '^DATABASE_CONNECTION_URI=' .env | head -1 | cut -d'=' -f1)=***"
echo "SERVER_URL: $(grep '^SERVER_URL=' .env | head -1)"
echo "N8N_ENABLED: $(grep '^N8N_ENABLED=' .env | head -1)"
echo ""
echo "=== Fix complete ==="

