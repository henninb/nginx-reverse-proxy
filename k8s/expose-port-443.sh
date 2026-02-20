#!/bin/bash

# Script to expose port 443 on the host by forwarding to the NodePort
# This works around PodSecurity restrictions that prevent hostPort/hostNetwork

set -e

echo "Setting up port 443 forwarding for nginx-reverse-proxy..."

# Get the current NodePort for HTTPS
NODEPORT=$(kubectl get service nginx-reverse-proxy-nodeport -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')

echo "Current NodePort for HTTPS: $NODEPORT"

# Check if we have access to configure iptables (requires root on the node)
if ! command -v iptables &> /dev/null; then
    echo "Error: iptables not available. This script needs to run on the Kubernetes node."
    echo ""
    echo "To manually forward port 443 to NodePort $NODEPORT, run these commands on your Talos node:"
    echo ""
    echo "# Forward port 443 to NodePort"
    echo "iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port $NODEPORT"
    echo ""
    echo "# To make persistent, save iptables rules:"
    echo "iptables-save > /etc/iptables/rules.v4"
    echo ""
    exit 1
fi

echo "Configuring iptables rules..."

# Remove any existing rules for port 443
iptables -t nat -D PREROUTING -p tcp --dport 443 -j REDIRECT --to-port $NODEPORT 2>/dev/null || true

# Add new rule to forward port 443 to NodePort
iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port $NODEPORT

echo "✅ Port forwarding configured:"
echo "  Port 443 -> NodePort $NODEPORT (HTTPS)"
echo ""
echo "Test access:"
echo "  curl -k https://192.168.10.176:443/"
echo ""
echo "Note: These iptables rules are temporary and will be lost on reboot."
echo "For persistent rules on Talos, you'll need to configure them via Talos machine config."