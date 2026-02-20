# Kubernetes Deployment for Nginx Reverse Proxy

This directory contains Kubernetes manifests for deploying the nginx reverse proxy to a Kubernetes cluster.

## Prerequisites

1. **Kubernetes cluster** - Ensure you have access to a Kubernetes cluster
2. **kubectl** - Kubernetes command-line tool configured to access your cluster
3. **Docker** - For building the container image
4. **SSL Certificates** - Your SSL certificate files must be present in the parent directory:
   - `bhenning.fullchain.pem`
   - `bhenning.privkey.pem`
   - `brianhenning.fullchain.pem`
   - `brianhenning.privkey.pem`

## Quick Deployment

Run the automated deployment script from the project root directory:

```bash
./k8s/deploy.sh
```

## Manual Deployment

### 1. Build the Docker Image

```bash
docker build -t nginx-reverse-proxy:latest .
```

### 2. Create SSL Certificate Secrets

```bash
./k8s/create-secrets.sh
```

### 3. Apply Kubernetes Manifests

```bash
# Apply SSL secrets
kubectl apply -f k8s/ssl-certificates-secret.yaml
kubectl apply -f k8s/ssl-private-keys-secret.yaml

# Apply deployment
kubectl apply -f k8s/deployment.yaml

# Apply services
kubectl apply -f k8s/service.yaml

# Apply ingress
kubectl apply -f k8s/ingress.yaml
```

### 4. Using Kustomize (Alternative)

```bash
kubectl apply -k k8s/
```

## Files Description

- **`deployment.yaml`** - Main deployment configuration with 2 replicas
- **`service.yaml`** - Service configurations (LoadBalancer and NodePort)
- **`ingress.yaml`** - Ingress controller configuration for all domains
- **`certificates.yaml`** - Template for SSL certificate secrets
- **`create-secrets.sh`** - Script to generate SSL secrets from certificate files
- **`deploy.sh`** - Automated deployment script
- **`kustomization.yaml`** - Kustomize configuration for declarative management

## Configuration Details

### Deployment
- **Replicas**: 2 (for high availability)
- **Image**: `nginx-reverse-proxy:latest`
- **Ports**: 443 (HTTPS)
- **Resources**: 128Mi-256Mi memory, 100m-200m CPU
- **Health Checks**: Liveness and readiness probes on HTTPS endpoint

### Services
- **LoadBalancer**: For cloud environments with external load balancer support
- **NodePort**: For bare-metal or environments without LoadBalancer support
  - HTTPS: NodePort 30443
  - GitLab SSH: NodePort 30223

### SSL Certificates
- Certificates are mounted as Kubernetes secrets
- Separate secrets for public certificates and private keys
- Mounted to `/etc/ssl/certs/` and `/etc/ssl/private/` respectively

### Ingress
- Configured for all domains from the original nginx configuration
- Supports wildcard certificates for `*.bhenning.com` and `*.brianhenning.com`
- SSL redirect enabled
- Backend protocol set to HTTPS

## Supported Domains

The deployment handles the following domains:
- `pfsense.bhenning.com` / `pfsense.brianhenning.com`
- `vercel.bhenning.com` / `vercel.brianhenning.com`
- `www.bhenning.com`
- `netlify.bhenning.com`
- `finance.bhenning.com` / `finance.brianhenning.com`
- `gitlab.bhenning.com` / `gitlab.brianhenning.com`
- `ddwrt.bhenning.com` / `ddwrt.brianhenning.com`
- `jellyfin.bhenning.com` / `jellyfin.brianhenning.com`
- `proxmox.bhenning.com` / `proxmox.brianhenning.com`
- `switch0.bhenning.com` / `switch0.brianhenning.com`
- `switch1.bhenning.com` / `switch1.brianhenning.com`

## Monitoring and Troubleshooting

### Check Deployment Status
```bash
kubectl get deployments nginx-reverse-proxy
kubectl get pods -l app=nginx-reverse-proxy
kubectl get services nginx-reverse-proxy-service
kubectl get ingress nginx-reverse-proxy-ingress
```

### View Logs
```bash
kubectl logs -l app=nginx-reverse-proxy -f
```

### Test Connectivity
```bash
# Port forward to test locally
kubectl port-forward service/nginx-reverse-proxy-service 8443:443

# Test in another terminal
curl -k https://localhost:8443
```

### Debug Pod
```bash
kubectl exec -it <pod-name> -- /bin/sh
```

## Scaling

To scale the deployment:
```bash
kubectl scale deployment nginx-reverse-proxy --replicas=3
```

## Updates

To update the deployment with a new image:
```bash
# Build new image
docker build -t nginx-reverse-proxy:v2 .

# Update deployment
kubectl set image deployment/nginx-reverse-proxy nginx-reverse-proxy=nginx-reverse-proxy:v2
```

## Cleanup

To remove the deployment:
```bash
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete secret ssl-certificates ssl-private-keys
```

## Security Considerations

1. **SSL Certificates**: Ensure certificates are kept secure and rotated regularly
2. **RBAC**: Configure appropriate RBAC rules for the deployment
3. **Network Policies**: Consider implementing network policies to restrict traffic
4. **Image Security**: Regularly update the base nginx image and scan for vulnerabilities
5. **Secrets**: Use proper secret management (consider using external secret management systems)

## Notes

- The deployment assumes internal services (192.168.x.x) are reachable from the Kubernetes cluster
- For production use, consider using cert-manager for automatic certificate management
- Adjust resource limits and requests based on your traffic requirements
- Consider using Horizontal Pod Autoscaler (HPA) for automatic scaling based on metrics