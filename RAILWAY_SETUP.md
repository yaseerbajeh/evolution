# Railway Deployment - Environment Variables Setup

## Required Environment Variables

Set these environment variables in your Railway project:

### Database Configuration (REQUIRED)
```
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=postgresql://postgres.riawxujhxscgcqybgytm:4oFL6S4JDfm2nOSx@aws-1-ap-southeast-2.pooler.supabase.com:6543/postgres?sslmode=require
DATABASE_CONNECTION_CLIENT_NAME=evolution
```

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
3. **DATABASE_CONNECTION_URI**: Use your Supabase connection string (Connection Pooler recommended)
4. **AUTHENTICATION_API_KEY**: Change this to a secure random string for production

## After Setting Variables

Railway will automatically restart your service. Check the logs to verify:
- Database connection is successful
- Migrations are applied
- Server starts on port 8080

