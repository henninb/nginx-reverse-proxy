#!/bin/bash

# Kubernetes deployment script for nginx-reverse-proxy
# Uses Podman for building (no daemon required)

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

# Check if podman is available
if ! command -v podman &> /dev/null; then
    echo "Error: podman is not installed or not in PATH"
    exit 1
fi

# Check if connected to a Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Not connected to a Kubernetes cluster"
    exit 1
fi

# Build image locally with Podman
echo "Building Docker image with Podman..."
podman build -t nginx-reverse-proxy:latest .

# Save image to tar file
echo "Saving image to tar file..."
podman save nginx-reverse-proxy:latest -o /tmp/nginx-reverse-proxy.tar

# Copy to control plane node
echo "Copying image to control plane node..."
scp /tmp/nginx-reverse-proxy.tar debian-k8s-cp-01:/tmp/

# Load image on control plane
echo "Loading image on control plane node..."
ssh debian-k8s-cp-01 "sudo ctr -n k8s.io images import /tmp/nginx-reverse-proxy.tar"

# Copy to worker node
echo "Copying image to worker node..."
scp /tmp/nginx-reverse-proxy.tar debian-k8s-worker-01:/tmp/

# Load image on worker
echo "Loading image on worker node..."
ssh debian-k8s-worker-01 "sudo ctr -n k8s.io images import /tmp/nginx-reverse-proxy.tar"

# Clean up tar file
echo "Cleaning up temporary files..."
rm /tmp/nginx-reverse-proxy.tar
ssh debian-k8s-cp-01 "rm /tmp/nginx-reverse-proxy.tar"
ssh debian-k8s-worker-01 "rm /tmp/nginx-reverse-proxy.tar"

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
