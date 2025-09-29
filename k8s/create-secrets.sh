#!/bin/bash

# Script to create Kubernetes secrets for SSL certificates
# Run this script from the nginx-reverse-proxy directory

set -e

echo "Creating SSL certificate secrets for Kubernetes..."

# Check if certificate files exist
if [[ ! -f "bhenning.fullchain.pem" || ! -f "bhenning.privkey.pem" ]]; then
    echo "Error: bhenning certificate files not found!"
    echo "Please ensure the following files exist in the current directory:"
    echo "  - bhenning.fullchain.pem"
    echo "  - bhenning.privkey.pem"
    exit 1
fi

if [[ ! -f "brianhenning.fullchain.pem" || ! -f "brianhenning.privkey.pem" ]]; then
    echo "Error: brianhenning certificate files not found!"
    echo "Please ensure the following files exist in the current directory:"
    echo "  - brianhenning.fullchain.pem"
    echo "  - brianhenning.privkey.pem"
    exit 1
fi

# Create secrets for SSL certificates
echo "Creating ssl-certificates secret..."
kubectl create secret generic ssl-certificates \
  --from-file=bhenning.fullchain.pem=bhenning.fullchain.pem \
  --from-file=brianhenning.fullchain.pem=brianhenning.fullchain.pem \
  --dry-run=client -o yaml > k8s/ssl-certificates-secret.yaml

echo "Creating ssl-private-keys secret..."
kubectl create secret generic ssl-private-keys \
  --from-file=bhenning.privkey.pem=bhenning.privkey.pem \
  --from-file=brianhenning.privkey.pem=brianhenning.privkey.pem \
  --dry-run=client -o yaml > k8s/ssl-private-keys-secret.yaml

echo "SSL certificate secrets created successfully!"
echo "Files created:"
echo "  - k8s/ssl-certificates-secret.yaml"
echo "  - k8s/ssl-private-keys-secret.yaml"
echo ""
echo "To apply these secrets to your cluster, run:"
echo "  kubectl apply -f k8s/ssl-certificates-secret.yaml"
echo "  kubectl apply -f k8s/ssl-private-keys-secret.yaml"