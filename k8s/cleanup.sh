#!/bin/bash

# Kubernetes cleanup script for nginx-reverse-proxy
# Run this script to remove all nginx-reverse-proxy resources

set -e

echo "========================================="
echo "Cleaning up nginx-reverse-proxy from Kubernetes"
echo "========================================="

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

echo "Removing Kubernetes resources..."

# Remove in reverse order
echo "Removing Ingress..."
kubectl delete -f k8s/ingress.yaml --ignore-not-found=true

echo "Removing Services..."
kubectl delete -f k8s/service.yaml --ignore-not-found=true

echo "Removing Deployment..."
kubectl delete -f k8s/deployment.yaml --ignore-not-found=true

echo "Removing SSL Secrets..."
kubectl delete secret ssl-certificates --ignore-not-found=true
kubectl delete secret ssl-private-keys --ignore-not-found=true

echo "Removing generated secret files..."
rm -f k8s/ssl-certificates-secret.yaml
rm -f k8s/ssl-private-keys-secret.yaml

echo "========================================="
echo "Cleanup completed successfully!"
echo "========================================="

echo "Verifying cleanup..."
kubectl get deployments -l app=nginx-reverse-proxy || echo "No deployments found (expected)"
kubectl get services -l app=nginx-reverse-proxy || echo "No services found (expected)"
kubectl get pods -l app=nginx-reverse-proxy || echo "No pods found (expected)"