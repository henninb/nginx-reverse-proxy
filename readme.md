# Nginx Reverse Proxy

A Docker-based nginx reverse proxy configuration for routing traffic to multiple internal services with DNS failover support.

## Features

- SSL/TLS termination with custom certificates
- HTTP/2 support
- Reverse proxy for multiple services (GitLab, Finance, Proxmox, pfSense, switches)
- **DNS Priority & Failover**: Local LAN DNS takes priority, automatically falls back to Cloudflare when unreachable
- Health check endpoints for monitoring
- Automated deployment scripts
- Docker containerized deployment

## Quick Start

### 1. Automated Deployment (Recommended)
```bash
# Deploy to debian-dockerserver with failover configuration
./run-docker.sh

# Or use the advanced management script
./manage.sh deploy
```

### 2. Manual Docker Commands
```bash
docker build -t nginx-reverse-proxy .
docker run --name=nginx-reverse-proxy -h nginx-reverse-proxy --restart unless-stopped -p 443:443 -d nginx-reverse-proxy
```

### 3. Docker Compose
```bash
./manage.sh compose
# or
docker-compose up -d --build
```

## Services Configured

- **Finance App**: `finance.bhenning.com`, `finance.brianhenning.com` (with DNS failover)
- **GitLab**: `gitlab.bhenning.com`, `gitlab.brianhenning.com`
- **Proxmox**: `proxmox.bhenning.com`, `proxmox.brianhenning.com`
- **pfSense**: `pfsense.bhenning.com`, `pfsense.brianhenning.com`
- **Jellyfin**: `jellyfin.bhenning.com`, `jellyfin.brianhenning.com`
- **Network Switches**: `switch0.bhenning.com`, `switch1.bhenning.com`
- **DD-WRT Router**: `ddwrt.bhenning.com`, `ddwrt.brianhenning.com`

### DNS Failover Configuration

The Finance application (`finance.bhenning.com`) is configured with intelligent DNS failover:
- **Primary**: Local LAN backend (`192.168.10.10:8443`)
- **Fallback**: Cloudflare GCP backend (`34.132.189.202:443`)
- **Health Check**: `/health` endpoint for monitoring
- **Auto-failover**: Triggers on connection errors, timeouts, and server errors (500, 502, 503, 504)

## Certificate Management

Place your SSL certificates in the following locations:
- `/etc/ssl/certs/bhenning.fullchain.pem`
- `/etc/ssl/private/bhenning.privkey.pem`
- `/etc/ssl/certs/brianhenning.fullchain.pem`
- `/etc/ssl/private/brianhenning.privkey.pem`

## Management Scripts

### run-docker.sh
Automated deployment script for quick deployment:
```bash
./run-docker.sh    # Deploy with DNS failover configuration
```

### manage.sh
Advanced management script with multiple commands:
```bash
./manage.sh deploy    # Deploy using Docker run (default)
./manage.sh compose   # Deploy using docker-compose
./manage.sh build     # Build image only
./manage.sh start     # Start existing container
./manage.sh stop      # Stop container
./manage.sh restart   # Restart container
./manage.sh logs      # Show container logs
./manage.sh status    # Show container status
./manage.sh test      # Test endpoints
./manage.sh clean     # Clean up containers and images
./manage.sh help      # Show help message
```

## Useful Commands

### Generate Basic Auth Credentials
```bash
echo -n 'username:password' | base64
```

### Test Endpoints
```bash
# Test health endpoint
curl -k -I https://finance.bhenning.com/health

# Test main endpoint
curl -k -I https://finance.bhenning.com/
```

### Container Commands
```bash
# Check container logs
ssh debian-dockerserver 'docker logs nginx-reverse-proxy'

# Check NGINX configuration
ssh debian-dockerserver 'docker exec nginx-reverse-proxy nginx -t'

# Reload NGINX configuration
ssh debian-dockerserver 'docker exec nginx-reverse-proxy nginx -s reload'
```

## Security Notes

- Update certificates regularly
- Review proxy configurations for security best practices
- Monitor access logs for suspicious activity


## servers

- bh-site5.netlify.app
- nextjs-website.pages.dev
- nextjs-website-alpha-weld.vercel.app
