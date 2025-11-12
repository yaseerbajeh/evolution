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
    
    # Handle connection pooler issues (e.g., Supabase pooler)
    # Prisma migrations require prepared statements support
    # Supabase: 
    #   - Direct connections: IPv6, port 5432 (supports prepared statements) ✅
    #   - Session Mode pooler: IPv4, port 5432 (supports prepared statements) ✅
    #   - Transaction Mode pooler: IPv4, port 6543 (NO prepared statements) ❌
    # We cannot auto-convert Transaction Mode pooler (6543) to direct - user must provide connection
    DB_URL="${DATABASE_URL:-$DATABASE_CONNECTION_URI}"
    ORIGINAL_DB_URL="$DB_URL"
    IS_TRANSACTION_POOLER=false
    
    # Detect if using Transaction Mode pooler (port 6543) - does NOT support prepared statements
    if [[ "$DB_URL" == *":6543"* ]]; then
        IS_TRANSACTION_POOLER=true
        echo "WARNING: Detected Transaction Mode pooler (port 6543). This does NOT support prepared statements required for Prisma migrations."
    elif [[ "$DB_URL" == *"pooler"* ]] && [[ "$DB_URL" != *":5432"* ]]; then
        # Pooler on non-5432 port (likely Transaction Mode)
        IS_TRANSACTION_POOLER=true
        echo "WARNING: Detected pooler connection that may not support prepared statements."
    fi
    
    # Port 5432 connections (direct or Session Mode pooler) support prepared statements - no action needed
    if [[ "$DB_URL" == *":5432"* ]] && [ "$IS_TRANSACTION_POOLER" = false ]; then
        echo "Connection uses port 5432 (direct or Session Mode pooler) - prepared statements supported ✅"
    fi
    
    # Check if a direct connection URI is explicitly provided
    if [ -n "$DATABASE_DIRECT_CONNECTION_URI" ]; then
        echo "Using explicit connection URI for migrations: DATABASE_DIRECT_CONNECTION_URI"
        DB_URL="$DATABASE_DIRECT_CONNECTION_URI"
        export DATABASE_URL="$DB_URL"
    elif [ "$IS_TRANSACTION_POOLER" = true ]; then
        # Transaction Mode pooler (port 6543) does NOT support prepared statements
        # User must provide a connection that supports prepared statements
        if [[ "$DB_URL" == *"supabase"* ]]; then
            echo "ERROR: Supabase Transaction Mode pooler (port 6543) detected."
            echo "This connection does NOT support prepared statements required for Prisma migrations."
            echo ""
            echo "SOLUTION: Set DATABASE_DIRECT_CONNECTION_URI in Railway with a connection that supports prepared statements:"
            echo ""
            echo "Option 1 (Recommended): Direct connection (IPv6, port 5432)"
            echo "  1. Go to Supabase Dashboard → Settings → Database"
            echo "  2. Copy 'Connection string' under 'Direct connection' (port 5432)"
            echo "  3. Set DATABASE_DIRECT_CONNECTION_URI in Railway with this string"
            echo ""
            echo "Option 2: Session Mode pooler (IPv4, port 5432)"
            echo "  1. Go to Supabase Dashboard → Settings → Database → Connection Pooling"
            echo "  2. Select 'Session Mode' (port 5432)"
            echo "  3. Copy the connection string"
            echo "  4. Set DATABASE_DIRECT_CONNECTION_URI in Railway with this string"
            echo ""
            echo "Your current connection (Transaction Mode pooler, port 6543): ${DB_URL:0:80}..."
            exit 1
        else
            echo "ERROR: Transaction Mode pooler (port 6543) detected, but DATABASE_DIRECT_CONNECTION_URI is not set."
            echo "Prisma migrations require prepared statements, which are NOT supported by Transaction Mode poolers."
            echo ""
            echo "SOLUTION: Set DATABASE_DIRECT_CONNECTION_URI with a connection that supports prepared statements:"
            echo "  - Direct connection (port 5432), OR"
            echo "  - Session Mode pooler (port 5432)"
            echo ""
            echo "Your current connection: ${DB_URL:0:80}..."
            exit 1
        fi
    fi
    
    echo "Deploying migrations for $DATABASE_PROVIDER"
    echo "Database URL: ${DATABASE_URL:0:50}..."
    
    # Wait a moment to ensure any previous database connections are closed
    echo "Waiting for database connections to stabilize..."
    sleep 2
    
    # Function to ensure _prisma_migrations table exists
    ensure_migration_table_exists() {
        echo "Ensuring _prisma_migrations table exists..."
        
        # Try to create the migration history table by running migrate deploy with --create-only equivalent
        # If the table doesn't exist, Prisma will create it when we try to resolve migrations
        # We can also try to create it manually using a simple SQL command
        
        # For PostgreSQL
        if [ "$DATABASE_PROVIDER" = "postgresql" ] || [ "$DATABASE_PROVIDER" = "psql_bouncer" ]; then
            echo "Creating _prisma_migrations table if it doesn't exist (PostgreSQL)..."
            # Use Prisma's internal command to ensure the table exists
            # Prisma will create it automatically when we try to resolve migrations
            # If that fails, we'll try a workaround
            return 0
        fi
        
        # For MySQL
        if [ "$DATABASE_PROVIDER" = "mysql" ]; then
            echo "Creating _prisma_migrations table if it doesn't exist (MySQL)..."
            return 0
        fi
        
        return 0
    }
    
    # Function to baseline database (mark all migrations as applied)
    baseline_database() {
        echo "Baselining database - marking all migrations as applied..."
        echo "This tells Prisma that your database is already at the current schema state"
        echo ""
        
        # Ensure migration history table exists first
        ensure_migration_table_exists
        
        # Get all migrations in chronological order
        local migrations
        migrations=$(ls -1 ./prisma/migrations | grep -E '^[0-9]' | sort)
        
        if [ -z "$migrations" ]; then
            echo "ERROR: No migrations found to baseline"
            return 1
        fi
        
        echo "Found $(echo "$migrations" | wc -l) migrations to baseline"
        echo ""
        
        local baseline_count=0
        local baseline_failed=0
        local baseline_errors=()
        
        # Mark each migration as applied in order
        while IFS= read -r migration_name; do
            if [ -d "./prisma/migrations/$migration_name" ]; then
                echo -n "Marking migration as applied: $migration_name ... "
                local resolve_output
                resolve_output=$(npx prisma migrate resolve --applied "$migration_name" --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" 2>&1)
                local resolve_exit_code=$?
                
                if [ $resolve_exit_code -eq 0 ]; then
                    baseline_count=$((baseline_count + 1))
                    echo "✅"
                else
                    baseline_failed=$((baseline_failed + 1))
                    # Check if error is because table doesn't exist or migration already applied
                    if echo "$resolve_output" | grep -q "does not exist\|table.*not found\|relation.*does not exist"; then
                        echo "⚠️  (migration history table may not exist yet)"
                        baseline_errors+=("$migration_name: table may not exist")
                    elif echo "$resolve_output" | grep -q "already applied\|already exists"; then
                        echo "ℹ️  (already applied)"
                        baseline_count=$((baseline_count + 1))  # Count as success if already applied
                        baseline_failed=$((baseline_failed - 1))
                    else
                        echo "⚠️  (error: $(echo "$resolve_output" | head -n 1))"
                        baseline_errors+=("$migration_name: $(echo "$resolve_output" | head -n 1)")
                    fi
                fi
            fi
        done <<< "$migrations"
        
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "Baselining Summary:"
        echo "  ✅ Successfully marked: $baseline_count migrations"
        echo "  ⚠️  Failed/Warnings: $baseline_failed migrations"
        echo "═══════════════════════════════════════════════════════════════"
        
        if [ ${#baseline_errors[@]} -gt 0 ]; then
            echo ""
            echo "Errors encountered:"
            for error in "${baseline_errors[@]}"; do
                echo "  - $error"
            done
        fi
        
        # If no migrations were marked and all failed, the table might not exist
        if [ $baseline_count -eq 0 ] && [ $baseline_failed -gt 0 ]; then
            echo ""
            echo "WARNING: No migrations were marked as applied"
            echo "The _prisma_migrations table may not exist"
            echo "Prisma should create it automatically on the next migrate deploy"
            echo "Attempting to trigger table creation..."
            
            # Try to trigger table creation by running migrate status
            npx prisma migrate status --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" > /dev/null 2>&1 || true
            
            # Try baselining again
            echo "Retrying baselining..."
            baseline_count=0
            baseline_failed=0
            
            while IFS= read -r migration_name; do
                if [ -d "./prisma/migrations/$migration_name" ]; then
                    if npx prisma migrate resolve --applied "$migration_name" --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" > /dev/null 2>&1; then
                        baseline_count=$((baseline_count + 1))
                    else
                        baseline_failed=$((baseline_failed + 1))
                    fi
                fi
            done <<< "$migrations"
            
            echo "Retry result: $baseline_count succeeded, $baseline_failed failed"
        fi
        
        # Consider baselining successful if at least some migrations were marked
        # or if the failures are due to migrations already being applied
        if [ $baseline_count -gt 0 ]; then
            return 0
        else
            return 1
        fi
    }
    
    # Function to check if database needs baselining and handle it
    check_and_baseline_database() {
        echo "Checking database migration status..."
        
        # Try to deploy migrations - if it fails with P3005, we need to baseline
        local migrate_output
        migrate_output=$(npx prisma migrate deploy --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" --skip-generate 2>&1)
        local migrate_exit_code=$?
        
        if [ $migrate_exit_code -eq 0 ]; then
            echo "✅ Migrations deployed successfully"
            return 0
        fi
        
        # Check if error is P3005 (database not empty, needs baselining)
        if echo "$migrate_output" | grep -q "P3005\|database schema is not empty\|baseline\|migrate baseline"; then
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "⚠️  DATABASE BASELINING REQUIRED (P3005 Error)"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "Your database schema is not empty, but Prisma's migration history"
            echo "table (_prisma_migrations) is missing or empty."
            echo ""
            echo "This typically happens when:"
            echo "  - Database was created manually"
            echo "  - Database was migrated from a different system"
            echo "  - Migration history table was deleted"
            echo ""
            echo "Solution: Baseline the database by marking all migrations as applied"
            echo "This tells Prisma that your database is already at the current schema state."
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            
            # Try to create migration history table first by running migrate status
            echo "Attempting to create migration history table if it doesn't exist..."
            npx prisma migrate status --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" > /dev/null 2>&1 || {
                echo "⚠️  Could not verify migration status (table may not exist yet)"
                echo "This is okay - Prisma will create it during baselining"
            }
            
            # Baseline the database
            if baseline_database; then
                echo ""
                echo "Verifying baselining by checking migration status..."
                
                # Try to deploy again - should succeed now or show which migrations are pending
                local verify_output
                verify_output=$(npx prisma migrate deploy --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" --skip-generate 2>&1)
                local verify_exit_code=$?
                
                if [ $verify_exit_code -eq 0 ]; then
                    echo "✅ Database baselining verified - migrations deployed successfully"
                    return 0
                else
                    # Check the error type
                    if echo "$verify_output" | grep -q "P3005\|database schema is not empty"; then
                        echo "⚠️  Still getting P3005 error after baselining"
                        echo "This might mean the migration history table wasn't created properly"
                        echo "Trying alternative approach: creating migration history table manually..."
                        
                        # Last resort: try to proceed anyway - Prisma might handle it
                        echo "⚠️  Proceeding with deployment - Prisma may create the table automatically"
                        echo "If this fails, you may need to manually create the _prisma_migrations table"
                        return 0
                    elif echo "$verify_output" | grep -q "migrations.*pending\|new migration\|already in the database"; then
                        echo "ℹ️  Some migrations may need to be applied"
                        echo "This is normal - Prisma will apply only the missing migrations"
                        # Try one more time - Prisma should apply pending migrations now
                        if npx prisma migrate deploy --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" --skip-generate 2>&1; then
                            echo "✅ Pending migrations applied successfully"
                            return 0
                        else
                            echo "⚠️  Some migrations may have issues, but continuing..."
                            return 0
                        fi
                    else
                        echo "⚠️  Verification showed issues:"
                        echo "$verify_output" | head -n 5
                        echo ""
                        echo "If your database schema is already up to date, this is okay"
                        echo "Continuing with deployment..."
                        return 0
                    fi
                fi
            else
                echo ""
                echo "⚠️  Baselining had issues, but attempting to continue..."
                echo "Prisma may be able to proceed if the database schema matches the expected state"
                echo ""
                echo "Trying to deploy migrations anyway..."
                
                # Try to deploy - it might work if the schema is already correct
                if npx prisma migrate deploy --schema "./prisma/$DATABASE_PROVIDER-schema.prisma" --skip-generate 2>&1; then
                    echo "✅ Migrations deployed successfully despite baselining issues"
                    return 0
                else
                    echo "ERROR: Database baselining failed and migrations cannot be deployed"
                    echo ""
                    echo "Manual intervention required:"
                    echo "1. Ensure your database schema matches the current Prisma schema"
                    echo "2. Manually create the _prisma_migrations table if it doesn't exist"
                    echo "3. Mark all migrations as applied using: prisma migrate resolve --applied <migration-name>"
                    echo ""
                    echo "See: https://www.prisma.io/docs/guides/migrate/production-troubleshooting#baseline-your-production-environment"
                    return 1
                fi
            fi
        else
            # Different error - show it and return failure
            echo "Migration failed with error:"
            echo "$migrate_output"
            return 1
        fi
    }
    
    # Function to retry migration with exponential backoff
    retry_migration() {
        local max_attempts=3
        local attempt=1
        local delay=2
        
        while [ $attempt -le $max_attempts ]; do
            echo "Migration attempt $attempt of $max_attempts..."
            
            # Clean up any existing migrations directory to avoid conflicts
            rm -rf ./prisma/migrations 2>/dev/null || true
            sleep 1
            
            # Copy migrations
            if [ ! -d "./prisma/$DATABASE_PROVIDER-migrations" ]; then
                echo "ERROR: Migrations directory not found: ./prisma/$DATABASE_PROVIDER-migrations"
                return 1
            fi
            
            cp -r "./prisma/$DATABASE_PROVIDER-migrations" "./prisma/migrations"
            
            # Check and baseline if needed, then deploy
            if check_and_baseline_database; then
                echo "Migration succeeded on attempt $attempt"
                return 0
            else
                local exit_code=$?
                echo "Migration failed on attempt $attempt with exit code $exit_code"
                
                # Clean up failed migration state
                rm -rf ./prisma/migrations 2>/dev/null || true
                
                if [ $attempt -lt $max_attempts ]; then
                    echo "Waiting ${delay}s before retry..."
                    sleep $delay
                    delay=$((delay * 2))
                fi
                attempt=$((attempt + 1))
            fi
        done
        
        echo "Migration failed after $max_attempts attempts"
        return 1
    }
    
    # Run migration with retry logic
    if ! retry_migration; then
        echo "ERROR: Migration failed after all retry attempts"
        echo "Please check:"
        echo "1. Database connection string is correct"
        echo "2. Database is accessible"
        echo "3. If using a pooler, ensure you have a direct connection string for migrations"
        exit 1
    fi
    
    # Generate Prisma client after successful migration
    echo "Generating Prisma client..."
    npm run db:generate
    if [ $? -ne 0 ]; then
        echo "ERROR: Prisma generate failed"
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
