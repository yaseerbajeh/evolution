# Railway Deployment - Environment Variables Setup

## Required Environment Variables

Set these environment variables in your Railway project:

### Database Configuration (REQUIRED)
```
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=postgresql://postgres.xxx:password@aws-0-region.pooler.supabase.com:6543/postgres?sslmode=require
DATABASE_CONNECTION_CLIENT_NAME=evolution
```

**IMPORTANT for Supabase users:**
- **DATABASE_CONNECTION_URI**: Use your Supabase pooler connection (IPv4, port 6543) for regular database operations
- **DATABASE_DIRECT_CONNECTION_URI** (REQUIRED for migrations): Use your Supabase direct connection for Prisma migrations
  - **Option 1 (Recommended)**: Direct connection (IPv6, port 5432)
    - Get this from: Supabase Dashboard → Settings → Database → Direct connection
    - Requires IPv6 support (Railway supports IPv6)
  - **Option 2 (If IPv6 not available)**: Session Mode pooler (IPv4, port 5432)
    - Get this from: Supabase Dashboard → Settings → Database → Connection Pooling → Session Mode
    - Supports prepared statements (unlike Transaction Mode pooler on port 6543)
  - Prisma migrations require prepared statements, which are only supported by direct connections or session mode pooler
  - Direct connections use IPv6, Transaction Mode pooler uses IPv4 - they cannot be auto-converted

### Server Configuration
```
SERVER_NAME=evolution
SERVER_TYPE=http
SERVER_PORT=8080
SERVER_URL=https://your-app-name.up.railway.app
SERVER_DISABLE_DOCS=false
SERVER_DISABLE_MANAGER=false
```

### Authentication (REQUIRED)
```
AUTHENTICATION_API_KEY=BQYHJGJHJ
AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false
```

### Cache Configuration
```
CACHE_REDIS_ENABLED=false
CACHE_LOCAL_ENABLED=true
CACHE_LOCAL_TTL=86400
```

### Database Save Settings
```
DATABASE_SAVE_DATA_INSTANCE=true
DATABASE_SAVE_DATA_NEW_MESSAGE=true
DATABASE_SAVE_MESSAGE_UPDATE=true
DATABASE_SAVE_DATA_CONTACTS=true
DATABASE_SAVE_DATA_CHATS=true
DATABASE_SAVE_DATA_HISTORIC=true
DATABASE_SAVE_DATA_LABELS=true
DATABASE_SAVE_IS_ON_WHATSAPP=true
DATABASE_SAVE_IS_ON_WHATSAPP_DAYS=7
DATABASE_DELETE_MESSAGE=false
```

### CORS Configuration
```
CORS_ORIGIN=*
CORS_METHODS=POST,GET,PUT,DELETE
CORS_CREDENTIALS=true
```

## How to Set Environment Variables in Railway

1. Go to your Railway project dashboard
2. Click on your service
3. Go to the "Variables" tab
4. Click "New Variable" for each variable above
5. Add the variable name and value
6. Click "Add" to save
7. Railway will automatically redeploy with the new variables

## Important Notes

1. **DATABASE_PROVIDER**: Must be exactly `postgresql` (lowercase, no spaces)
2. **SERVER_URL**: Update this to your Railway app URL after first deployment
3. **DATABASE_CONNECTION_URI**: Use your database connection string for regular operations
   - **For Supabase**: Use the pooler connection (IPv4, port 6543) for regular database operations
   - **For Railway PostgreSQL**: Use the connection string provided by Railway
   - **For other providers**: Use your standard connection string
4. **DATABASE_DIRECT_CONNECTION_URI** (REQUIRED for Supabase pooler users):
   - **For Supabase**: You MUST set this with your direct connection string (IPv6, port 5432)
   - **Why**: Prisma migrations require prepared statements, which are only supported by direct connections
   - **How to get it**: Supabase Dashboard → Settings → Database → Direct connection
   - **Note**: Direct connections use IPv6, pooler uses IPv4 - they cannot be auto-converted
   - **For Railway PostgreSQL**: Not needed (Railway provides direct connections by default)
5. **AUTHENTICATION_API_KEY**: Change this to a secure random string for production

## Troubleshooting Migration Errors

### Error: "prepared statement 's0' already exists"

This error occurs when using a connection pooler for Prisma migrations. Prisma migrations require prepared statements, which are only supported by direct connections.

**For Supabase users:**
- **Problem**: Supabase pooler (IPv4, port 6543) does not support prepared statements
- **Solution**: You MUST set `DATABASE_DIRECT_CONNECTION_URI` with your Supabase direct connection (IPv6, port 5432)
- **How to get direct connection**:
  1. Go to Supabase Dashboard
  2. Select your project
  3. Click "Settings" → "Database"
  4. Copy the "Connection string" under "Direct connection" (not pooler)
  5. Set this as `DATABASE_DIRECT_CONNECTION_URI` in Railway

**For other pooler users:**
- Set `DATABASE_DIRECT_CONNECTION_URI` with a direct connection string (not pooler)
- Ensure the direct connection supports prepared statements

**The deployment script will:**
1. Detect if you're using a pooler connection
2. Require `DATABASE_DIRECT_CONNECTION_URI` if a pooler is detected
3. Use the direct connection for migrations only
4. Retry migrations with exponential backoff if they fail
5. Clean up migration state between retries

### Error: "DATABASE_DIRECT_CONNECTION_URI is not set"

If you see this error, you need to set the direct connection URI:
1. Get your direct connection string from your database provider
2. Set `DATABASE_DIRECT_CONNECTION_URI` in Railway with this value
3. Redeploy your service

### Error: P3005 - "Database schema is not empty"

This error occurs when your database has tables but Prisma's migration history table (`_prisma_migrations`) is missing or empty.

**What happens automatically:**
- The deployment script detects this error
- It automatically baselines your database by marking all migrations as applied
- This tells Prisma that your database is already at the current schema state

**If automatic baselining fails:**
1. Ensure your database schema matches the current Prisma schema
2. Manually create the `_prisma_migrations` table if it doesn't exist
3. Mark migrations as applied using: `prisma migrate resolve --applied <migration-name>`

**See Prisma documentation:**
- https://www.prisma.io/docs/guides/migrate/production-troubleshooting#baseline-your-production-environment

## After Setting Variables

Railway will automatically restart your service. Check the logs to verify:
- Database connection is successful
- Migrations are applied
- Server starts on port 8080

