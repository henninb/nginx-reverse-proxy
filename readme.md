# Nginx Reverse Proxy

A Docker-based nginx reverse proxy configuration for routing traffic to multiple internal services.

## Features

- SSL/TLS termination with custom certificates
- HTTP/2 support
- Reverse proxy for multiple services (GitLab, Plex, Proxmox, pfSense, switches)
- Basic authentication support
- Docker containerized deployment

## Quick Start

1. **Build and run with Docker:**
   ```bash
   docker build -t nginx-proxy .
   docker run -d -p 443:443 -v /path/to/certs:/etc/ssl nginx-proxy
   ```

2. **Or use Docker Compose:**
   ```bash
   docker-compose up -d
   ```

## Services Configured

- **GitLab**: `gitlab.bhenning.com`
- **Plex**: `plex.lan`, `plex.proxy`
- **Proxmox**: `proxmox.bhenning.com`, `proxmox.brianhenning.com`
- **pfSense**: `pfsense.bhenning.com`, `pfsense.brianhenning.com`
- **Finance App**: `finance.bhenning.com`, `finance.brianhenning.com`
- **Network Switches**: `switch0.lan`, `switch1.lan`
- **DD-WRT Router**: `ddwrt.lan`, `ddwrt.proxy`

## Certificate Management

Place your SSL certificates in the following locations:
- `/etc/ssl/certs/bhenning.fullchain.pem`
- `/etc/ssl/private/bhenning.privkey.pem`
- `/etc/ssl/certs/brianhenning.fullchain.pem`
- `/etc/ssl/private/brianhenning.privkey.pem`

## Useful Commands

### Generate Basic Auth Credentials
```bash
echo -n 'username:password' | base64
```

### Check if Nginx Debug is Enabled
```bash
nginx -V 2>&1 | grep -- '--with-debug'
```

### Test Configuration
```bash
nginx -t
```

### Reload Configuration
```bash
nginx -s reload
```

## Security Notes

- Update certificates regularly
- Review proxy configurations for security best practices
- Monitor access logs for suspicious activity
