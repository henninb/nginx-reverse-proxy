#!/bin/bash
# Deploy nginx-reverse-proxy using local Kubernetes registry
# Requires podman on local machine

set -e

REGISTRY_HOST="debian-k8s-worker-02"
REGISTRY_PORT="5000"
IMAGE_NAME="nginx-reverse-proxy"
IMAGE_TAG="latest"
FULL_IMAGE="${REGISTRY_HOST}:${REGISTRY_PORT}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "========================================="
echo "Deploying nginx-reverse-proxy via Local Registry"
echo "========================================="

# Check if podman is available
if ! command -v podman &> /dev/null; then
    echo "Error: podman is not installed or not in PATH"
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
    exit 1
fi

# Check if registry is running
echo "Checking if registry is running..."
if ! kubectl get deployment registry -n kube-system &> /dev/null; then
    echo "Error: Registry not found in cluster. Please run:"
    echo "  cd ~/ansible/debian-kubernetes"
    echo "  ansible-playbook playbooks/deploy-registry.yml"
    exit 1
fi

# Build image locally with podman
echo "Building image with Podman..."
podman build -t ${IMAGE_NAME}:${IMAGE_TAG} .

# Tag for local registry
echo "Tagging image for registry..."
podman tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE}

# Push to local registry
echo "Pushing to local registry..."
podman push --tls-verify=false ${FULL_IMAGE}

# Create ConfigMap and Secrets
echo "Creating ConfigMap from nginx.conf..."
kubectl create configmap nginx-config --from-file=nginx.conf --dry-run=client -o yaml | kubectl apply -f -

echo "Creating SSL certificate secrets..."
./k8s/create-secrets.sh

# Create temporary deployment file with registry image
echo "Deploying to Kubernetes..."
cat k8s/deployment.yaml | sed "s|image: nginx:alpine|image: ${FULL_IMAGE}|" | kubectl apply -f -

echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-reverse-proxy || true

echo "========================================="
echo "Deployment completed!"
echo "========================================="

echo ""
echo "Deployment status:"
kubectl get deployments nginx-reverse-proxy

echo ""
echo "Pods:"
kubectl get pods -l app=nginx-reverse-proxy

echo ""
echo "To check logs:"
echo "  kubectl logs -l app=nginx-reverse-proxy -f"
