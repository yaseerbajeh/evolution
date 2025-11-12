# Evolution API - Hostinger VPS Deployment Guide

## Overview

This guide covers deploying Evolution API to a Hostinger VPS using Docker. The deployment uses Supabase for the database and exposes the API on port 8080.

## Prerequisites

- Hostinger VPS with Ubuntu 22.04 LTS (or similar)
- Root SSH access to VPS
- Supabase PostgreSQL database (or other PostgreSQL database)
- Domain name (optional, for SSL/HTTPS)

## VPS Specifications

- **VPS IP**: 72.60.92.80
- **OS**: Ubuntu 22.04 LTS (recommended)
- **Minimum Requirements**:
  - 2 vCPU
  - 2GB RAM
  - 20GB SSD
- **Recommended**:
  - 4 vCPU
  - 4GB RAM
  - 40GB SSD

## Quick Deployment

### Option 1: Automated Deployment Script

Use the provided deployment script for automated deployment:

```bash
# Make script executable
chmod +x deploy-hostinger.sh

# Run deployment
./deploy-hostinger.sh
```

### Option 2: Manual Deployment

Follow the manual steps below for more control.

## Manual Deployment Steps

### Step 1: Connect to VPS

```bash
ssh root@72.60.92.80
# Password: Riyadhyasser55@
```

### Step 2: Update System

```bash
apt update && apt upgrade -y
apt install -y curl wget git nano ufw
```

### Step 3: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Verify installation
docker --version
```

### Step 4: Install Docker Compose

```bash
# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
```

### Step 5: Clone Repository

```bash
# Clone your repository
cd ~
git clone https://github.com/yaseerbajeh/evolution.git evolution
cd evolution
```

### Step 6: Configure Environment Variables

```bash
# Copy environment template
cp env.example .env

# Edit .env file
nano .env
```

Update these critical variables in `.env`:

```env
# Server Configuration
SERVER_NAME=evolution
SERVER_TYPE=http
SERVER_PORT=8080
SERVER_URL=http://72.60.92.80:8080
SERVER_DISABLE_DOCS=false
SERVER_DISABLE_MANAGER=false

# Database (Supabase)
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=postgresql://postgres.riawxujhxscgcqybgytm:4oFL6S4JDfm2nOSx@aws-1-ap-southeast-2.pooler.supabase.com:6543/postgres?sslmode=require
DATABASE_CONNECTION_CLIENT_NAME=evolution

# Authentication
AUTHENTICATION_API_KEY=BQYHJGJHJ
AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=false

# Cache (Local cache - Redis disabled)
CACHE_REDIS_ENABLED=false
CACHE_LOCAL_ENABLED=true
CACHE_LOCAL_TTL=86400

# Database Save Settings
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

# CORS
CORS_ORIGIN=*
CORS_METHODS=POST,GET,PUT,DELETE
CORS_CREDENTIALS=true
```

### Step 7: Configure Docker Compose

Use the production docker-compose file:

```bash
# Copy production docker-compose file
cp docker-compose.production.yaml docker-compose.yaml
```

Or create `docker-compose.yaml` manually:

```yaml
version: "3.8"

services:
  api:
    container_name: evolution_api
    build:
      context: .
      dockerfile: Dockerfile
    restart: always
    ports:
      - "8080:8080"
    volumes:
      - evolution_instances:/evolution/instances
    env_file:
      - .env
    networks:
      - evolution-net
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:8080', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  evolution_instances:
    driver: local

networks:
  evolution-net:
    driver: bridge
```

### Step 8: Configure Firewall

```bash
# Enable firewall
ufw enable

# Allow SSH
ufw allow 22/tcp

# Allow Evolution API
ufw allow 8080/tcp

# Allow HTTP/HTTPS (for future domain setup)
ufw allow 80/tcp
ufw allow 443/tcp

# Check firewall status
ufw status
```

### Step 9: Build and Deploy

```bash
# Build and start containers
docker-compose up -d --build

# Watch logs
docker-compose logs -f
```

The first build will take 5-10 minutes. You should see:
- "Prisma generate succeeded"
- "Migration succeeded"
- Server running on port 8080

### Step 10: Verify Deployment

```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f api

# Test API
curl http://localhost:8080
```

Expected response:
```json
{
  "status": 200,
  "message": "Welcome to the Evolution API, it is working!",
  "version": "2.3.6",
  "clientName": "evolution",
  "manager": "http://72.60.92.80:8080/manager",
  "documentation": "https://doc.evolution-api.com"
}
```

## Accessing Your API

After deployment, your API will be available at:

- **API Endpoint**: http://72.60.92.80:8080
- **Manager Panel**: http://72.60.92.80:8080/manager
- **API Documentation**: http://72.60.92.80:8080/docs
- **Health Check**: http://72.60.92.80:8080

## Useful Commands

### Docker Compose Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View logs
docker-compose logs -f api

# View container status
docker-compose ps

# Rebuild after code changes
docker-compose up -d --build

# View resource usage
docker stats evolution_api
```

### SSH Commands

```bash
# Connect to VPS
ssh root@72.60.92.80

# View logs remotely
ssh root@72.60.92.80 "cd ~/evolution && docker-compose logs -f"

# Restart service remotely
ssh root@72.60.92.80 "cd ~/evolution && docker-compose restart"

# Check status remotely
ssh root@72.60.92.80 "cd ~/evolution && docker-compose ps"
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs api

# Check if port is in use
netstat -tulpn | grep 8080

# Check Docker status
docker ps -a
```

### Database Connection Errors

1. Verify `DATABASE_CONNECTION_URI` is correct in `.env`
2. Check Supabase database is accessible
3. Verify SSL mode is set: `?sslmode=require`
4. Check firewall allows outbound connections to Supabase

### Build Errors

```bash
# Clean build
docker-compose down
docker system prune -a
docker-compose up -d --build --no-cache
```

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill process (replace PID with actual process ID)
kill -9 PID

# Or change port in docker-compose.yaml and .env
```

### Memory Issues

If the VPS runs out of memory:

```bash
# Check memory usage
free -h

# Check Docker memory usage
docker stats

# Increase swap space (if needed)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## Updating the Application

### Update from GitHub

```bash
# SSH into VPS
ssh root@72.60.92.80

# Navigate to project directory
cd ~/evolution

# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose up -d --build
```

### Update Environment Variables

```bash
# Edit .env file
nano .env

# Restart container to apply changes
docker-compose restart
```

## Security Best Practices

1. **Change Default API Key**: Update `AUTHENTICATION_API_KEY` in `.env` to a secure random string
2. **Use SSH Keys**: Set up SSH key authentication instead of password
3. **Keep System Updated**: Regularly update system packages
4. **Monitor Logs**: Regularly check application logs for errors
5. **Backup Data**: Regularly backup WhatsApp instance data and database
6. **Firewall**: Keep firewall enabled and only open necessary ports
7. **SSL/HTTPS**: Set up SSL certificate when using a domain name

## Setting Up Domain and SSL (Optional)

### Step 1: Point Domain to VPS

1. Go to your domain registrar
2. Create A record pointing to `72.60.92.80`
3. Wait for DNS propagation (usually 5-30 minutes)

### Step 2: Install Nginx

```bash
# Install Nginx
apt install -y nginx

# Create Nginx configuration
nano /etc/nginx/sites-available/evolution-api
```

Add this configuration:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site:

```bash
# Create symbolic link
ln -s /etc/nginx/sites-available/evolution-api /etc/nginx/sites-enabled/

# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx
```

### Step 3: Install SSL Certificate

```bash
# Install Certbot
apt install -y certbot python3-certbot-nginx

# Get SSL certificate
certbot --nginx -d your-domain.com

# Test auto-renewal
certbot renew --dry-run
```

### Step 4: Update Environment Variables

Update `SERVER_URL` in `.env`:

```env
SERVER_URL=https://your-domain.com
```

Restart the container:

```bash
docker-compose restart
```

## Monitoring and Maintenance

### Check Application Status

```bash
# Check container status
docker-compose ps

# Check application logs
docker-compose logs -f api

# Check system resources
docker stats evolution_api
```

### Backup WhatsApp Instances

```bash
# Backup instances directory
tar -czf instances-backup-$(date +%Y%m%d).tar.gz evolution_instances/

# Restore instances
tar -xzf instances-backup-YYYYMMDD.tar.gz
```

### Database Backup

Since you're using Supabase, backups are handled by Supabase. However, you can export data:

```bash
# Connect to database and export
pg_dump $DATABASE_CONNECTION_URI > backup.sql

# Restore database
psql $DATABASE_CONNECTION_URI < backup.sql
```

## Support and Resources

- **Evolution API Documentation**: https://doc.evolution-api.com
- **GitHub Repository**: https://github.com/EvolutionAPI/evolution-api
- **Hostinger Support**: https://www.hostinger.com/contact
- **Supabase Documentation**: https://supabase.com/docs

## Common Issues and Solutions

### Issue: Container keeps restarting

**Solution**: Check logs for errors:
```bash
docker-compose logs api
```

### Issue: Database connection fails

**Solution**: 
1. Verify Supabase connection string
2. Check Supabase database is active
3. Verify SSL mode in connection string

### Issue: Port 8080 not accessible

**Solution**:
1. Check firewall rules: `ufw status`
2. Verify port is open: `ufw allow 8080/tcp`
3. Check if port is in use: `netstat -tulpn | grep 8080`

### Issue: Build fails with "husky: not found"

**Solution**: This is already fixed in the Dockerfile. Make sure you're using the latest version.

## Next Steps

After successful deployment:

1. **Create WhatsApp Instance**: Use the API to create your first WhatsApp instance
2. **Connect WhatsApp**: Scan QR code to connect your WhatsApp number
3. **Test API**: Test sending messages and other API endpoints
4. **Configure Webhooks**: Set up webhooks for real-time events (optional)
5. **Set Up Monitoring**: Configure monitoring and alerts (optional)

## Deployment Checklist

- [ ] VPS configured with Ubuntu 22.04 LTS
- [ ] Docker and Docker Compose installed
- [ ] Repository cloned from GitHub
- [ ] Environment variables configured in `.env`
- [ ] Docker Compose configuration created
- [ ] Firewall configured
- [ ] Containers built and started
- [ ] API accessible at http://72.60.92.80:8080
- [ ] Database connection verified
- [ ] WhatsApp instance creation tested
- [ ] Manager panel accessible

## Contact and Support

For issues or questions:
- Check Evolution API documentation
- Review application logs
- Check Supabase database status
- Contact Hostinger support for VPS issues

