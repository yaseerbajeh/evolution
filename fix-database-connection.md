# Fix Database Connection Issue

## Problem
Error: `FATAL: Tenant or user not found`

This error indicates that your Supabase database credentials are incorrect or the database is not accessible.

## Solutions

### Solution 1: Verify Supabase Project Status

1. Go to https://app.supabase.com
2. Check if your project is **active** (not paused)
3. If paused, click "Restore" to activate it
4. Free tier projects pause after 7 days of inactivity

### Solution 2: Get Fresh Connection String from Supabase

1. Go to your Supabase project dashboard
2. Navigate to **Settings** → **Database**
3. Scroll down to **Connection string**
4. Select **Connection pooling** tab
5. Copy the **URI** connection string
6. It should look like:
   ```
   postgresql://postgres.[PROJECT-REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres?sslmode=require
   ```

### Solution 3: Try Direct Connection (Not Pooler)

If the pooler doesn't work, try the direct connection:

1. In Supabase dashboard, go to **Settings** → **Database**
2. Select **Connection string** tab (not pooling)
3. Copy the **URI** connection string
4. It should look like:
   ```
   postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres?sslmode=require
   ```
5. Update your `.env` file:
   ```env
   DATABASE_CONNECTION_URI=postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres?sslmode=require
   ```

### Solution 4: Verify Database Password

1. In Supabase dashboard, go to **Settings** → **Database**
2. Scroll down to **Database password**
3. If you forgot the password, click **Reset database password**
4. Copy the new password and update your `.env` file

### Solution 5: Check Project Reference

Make sure your project reference in the connection string matches your actual Supabase project:
- Check the URL: `https://app.supabase.com/project/[PROJECT-REF]`
- The PROJECT-REF should match in your connection string

## Update .env File

After getting the correct connection string:

1. Open `.env` file
2. Update `DATABASE_CONNECTION_URI` with the new connection string
3. Save the file
4. Test the connection:
   ```bash
   node test-db-connection.js
   ```

## Test Connection

Run the test script to verify the connection:

```bash
node test-db-connection.js
```

If successful, you should see:
```
✅ Database connection successful!
✅ Database query successful!
```

## Common Issues

### Issue: Project is Paused
**Solution**: Go to Supabase dashboard and click "Restore" to activate the project

### Issue: Wrong Password
**Solution**: Reset the database password in Supabase dashboard

### Issue: Wrong Project Reference
**Solution**: Verify the project reference in the connection string matches your Supabase project

### Issue: Pooler Connection Failed
**Solution**: Try the direct connection (port 5432) instead of pooler (port 6543)

## Next Steps

Once the connection is working:
1. Run `npm run db:generate` to generate Prisma client
2. Run `npm run db:deploy` to apply migrations
3. Start the server: `npm start`

