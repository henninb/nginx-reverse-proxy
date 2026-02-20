# Nginx Reverse Proxy for Kubernetes

## Overview
Nginx reverse proxy deployed to Kubernetes with `hostNetwork: true` for direct port 443 access.

## Quick Start

### Deploy to Kubernetes
```bash
kubectl apply -f k8s/deployment.yaml
```

### Verify
```bash
kubectl get pods -l app=nginx-reverse-proxy
curl -k https://192.168.10.12:443
```

## Configuration

### Network Mode
- **hostNetwork: true** - Binds directly to host ports
- **Ports**: 443 (HTTPS)
- **Pinned to**: debian-k8s-worker-01

### DNS Resolution
- **Resolver**: `8.8.8.8 8.8.4.4` for external hostname resolution
- **Variables**: Uses `set $vercel_backend` for dynamic proxy_pass

### Health Checks
- **Type**: tcpSocket on port 443
- **Liveness**: 30s initial delay, 10s period
- **Readiness**: 5s initial delay, 5s period

## Files

- `nginx.conf` - Main nginx configuration
- `k8s/deployment.yaml` - Kubernetes deployment with ConfigMap

## Access

- **HTTPS**: `https://192.168.10.12:443`

## Important Notes

⚠️ **Do NOT add iptables NAT redirects** (443→30443) when using hostNetwork - it breaks direct port binding.

## Related

See `~/ansible/debian-k8/playbooks/README-nginx-reverse-proxy.md` for Ansible deployment details.
