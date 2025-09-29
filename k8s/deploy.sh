#!/bin/bash

# Kubernetes deployment script for nginx-reverse-proxy
# Run this script from the nginx-reverse-proxy root directory

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

# Create k8s directory if it doesn't exist
mkdir -p k8s

echo "Building Docker image..."
docker build -t nginx-reverse-proxy:latest .

# Tag for your registry if needed (uncomment and modify as needed)
# echo "Tagging image for registry..."
# docker tag nginx-reverse-proxy:latest your-registry.com/nginx-reverse-proxy:latest
# docker push your-registry.com/nginx-reverse-proxy:latest

echo "Creating SSL certificate secrets..."
./k8s/create-secrets.sh

echo "Applying Kubernetes manifests..."

# Apply in order
echo "Creating ConfigMap and Secrets..."
kubectl apply -f k8s/ssl-certificates-secret.yaml
kubectl apply -f k8s/ssl-private-keys-secret.yaml

echo "Creating Deployment..."
kubectl apply -f k8s/deployment.yaml

echo "Creating Services..."
kubectl apply -f k8s/service.yaml

echo "Creating Ingress..."
kubectl apply -f k8s/ingress.yaml

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-reverse-proxy

echo "========================================="
echo "Deployment completed successfully!"
echo "========================================="

echo "Checking deployment status..."
kubectl get deployments nginx-reverse-proxy
kubectl get services nginx-reverse-proxy-service
kubectl get pods -l app=nginx-reverse-proxy

echo ""
echo "To check logs, run:"
echo "  kubectl logs -l app=nginx-reverse-proxy -f"
echo ""
echo "To check ingress, run:"
echo "  kubectl get ingress nginx-reverse-proxy-ingress"
echo ""
echo "To test the service, run:"
echo "  kubectl port-forward service/nginx-reverse-proxy-service 8443:443"
echo "  curl -k https://localhost:8443"