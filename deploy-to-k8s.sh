#!/bin/bash

# Kubernetes deployment script for nginx-reverse-proxy
# Deploys to local Kubernetes cluster

set -e

echo "========================================="
echo "Deploying nginx-reverse-proxy to Kubernetes"
echo "========================================="

# Check if we're in the correct directory
if [[ ! -f "nginx.conf" ]] || [[ ! -f "Dockerfile" ]]; then
    echo "Error: Please run this script from the nginx-reverse-proxy root directory"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if connected to a Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Not connected to a Kubernetes cluster"
    echo "Please configure kubectl to connect to your cluster"
    exit 1
fi

# Alternative approach: Pull base image and manually create layers using ctr
# This avoids needing Docker or BuildKit

echo "Preparing to build image on control plane..."

# Copy project files to control plane
echo "Copying project files to control plane node..."
ssh debian-k8s-cp-01 "mkdir -p /tmp/nginx-reverse-proxy"
scp Dockerfile nginx.conf *.pem debian-k8s-cp-01:/tmp/nginx-reverse-proxy/

# Create a simple build script that uses ctr and tar
echo "Creating build script on control plane..."
ssh debian-k8s-cp-01 'cat > /tmp/nginx-reverse-proxy/build.sh << "BUILDSCRIPT"
#!/bin/bash
set -e

cd /tmp/nginx-reverse-proxy

# Pull nginx:alpine base image
echo "Pulling nginx:alpine base image..."
sudo ctr -n k8s.io images pull docker.io/library/nginx:alpine

# Export base image
echo "Exporting base image..."
sudo ctr -n k8s.io images export /tmp/nginx-base.tar docker.io/library/nginx:alpine

# Create a temporary directory for the new image
mkdir -p /tmp/nginx-build
cd /tmp/nginx-build

# Extract base image
echo "Extracting base image..."
tar -xf /tmp/nginx-base.tar

# Create Dockerfile equivalent manually
echo "Building custom layers..."
mkdir -p rootfs

# Extract the base filesystem
LAYER=$(jq -r ".[0].Layers[0]" manifest.json | cut -d/ -f1)
tar -xf ${LAYER}/layer.tar -C rootfs/

# Apply our changes (equivalent to Dockerfile commands)
rm -f rootfs/etc/nginx/nginx.conf
cp /tmp/nginx-reverse-proxy/nginx.conf rootfs/etc/nginx/nginx.conf
cp /tmp/nginx-reverse-proxy/bhenning.fullchain.pem rootfs/etc/ssl/certs/
cp /tmp/nginx-reverse-proxy/bhenning.privkey.pem rootfs/etc/ssl/private/
cp /tmp/nginx-reverse-proxy/brianhenning.fullchain.pem rootfs/etc/ssl/certs/
cp /tmp/nginx-reverse-proxy/brianhenning.privkey.pem rootfs/etc/ssl/private/

# Create new layer tar
echo "Creating new image layer..."
cd rootfs
tar -czf /tmp/nginx-reverse-proxy.tar.gz .
cd /tmp

# Import as new image using ctr
echo "Importing final image..."
sudo ctr -n k8s.io images import --base-name docker.io/library/nginx:alpine --index-name docker.io/library/nginx-reverse-proxy:latest /tmp/nginx-reverse-proxy.tar.gz || {
    # Fallback: use simpler import
    cd /tmp/nginx-build/rootfs
    tar -cf /tmp/nginx-reverse-proxy-final.tar .
    sudo ctr -n k8s.io images import /tmp/nginx-reverse-proxy-final.tar
}

# Cleanup
rm -rf /tmp/nginx-build /tmp/nginx-base.tar /tmp/nginx-reverse-proxy.tar.gz

echo "Image build complete"
BUILDSCRIPT
'

# Make build script executable and run it
echo "Building image on control plane..."
ssh debian-k8s-cp-01 "chmod +x /tmp/nginx-reverse-proxy/build.sh && /tmp/nginx-reverse-proxy/build.sh"

# Export the built image
echo "Exporting built image..."
ssh debian-k8s-cp-01 "sudo ctr -n k8s.io images export /tmp/nginx-reverse-proxy.tar docker.io/library/nginx-reverse-proxy:latest || sudo ctr -n k8s.io images export /tmp/nginx-reverse-proxy.tar nginx-reverse-proxy:latest"
ssh debian-k8s-cp-01 "sudo chmod 644 /tmp/nginx-reverse-proxy.tar"

# Copy to local machine and then to worker
echo "Copying image to worker node..."
scp debian-k8s-cp-01:/tmp/nginx-reverse-proxy.tar /tmp/
scp /tmp/nginx-reverse-proxy.tar debian-k8s-worker-01:/tmp/

# Import on worker
echo "Importing image on worker node..."
ssh debian-k8s-worker-01 "sudo ctr -n k8s.io images import /tmp/nginx-reverse-proxy.tar"

# Clean up
echo "Cleaning up temporary files..."
ssh debian-k8s-cp-01 "sudo rm -rf /tmp/nginx-reverse-proxy /tmp/nginx-reverse-proxy.tar"
ssh debian-k8s-worker-01 "rm /tmp/nginx-reverse-proxy.tar"
rm /tmp/nginx-reverse-proxy.tar

# Create secrets
echo "Creating SSL certificate secrets..."
./k8s/create-secrets.sh

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."

echo "Creating Secrets..."
kubectl apply -f k8s/ssl-certificates-secret.yaml
kubectl apply -f k8s/ssl-private-keys-secret.yaml

echo "Creating Deployment..."
kubectl apply -f k8s/deployment.yaml

echo "Creating Service..."
kubectl apply -f k8s/service.yaml

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-reverse-proxy || true

echo "========================================="
echo "Deployment completed!"
echo "========================================="

echo ""
echo "Deployment status:"
kubectl get deployments nginx-reverse-proxy

echo ""
echo "Service status:"
kubectl get services nginx-reverse-proxy-service

echo ""
echo "Pods:"
kubectl get pods -l app=nginx-reverse-proxy

echo ""
echo "To check logs:"
echo "  kubectl logs -l app=nginx-reverse-proxy -f"
echo ""
echo "To access the service:"
echo "  kubectl port-forward service/nginx-reverse-proxy-service 8443:443"
echo "  curl -k https://localhost:8443"
