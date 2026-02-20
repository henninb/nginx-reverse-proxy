# Exposing Port 443 on Talos Kubernetes

Your nginx reverse proxy is successfully deployed and running, but Kubernetes PodSecurity policies prevent direct port exposure via `hostPort` or `hostNetwork`. Here are the solutions to expose port 443:

## Current Status ✅
- **nginx-reverse-proxy is running** with 1 replica
- **NodePort service** exposes HTTPS on port **30443**
- **Service accessible** via: `https://192.168.10.176:30443`

## Solution Options

### Option 1: Use NodePort (Current Working Solution) ⭐ **RECOMMENDED**

Your service is already accessible via NodePort:
```bash
# Test current access
curl -k https://192.168.10.176:30443/

# Update your DNS/router to point to port 30443
# Or use this in your applications/browser
```

**Pros**: Works immediately, no additional configuration
**Cons**: Non-standard port (30443 instead of 443)

### Option 2: Talos Machine Config (Permanent Solution) 🎯 **BEST FOR PRODUCTION**

Update your Talos machine configuration to forward port 443:

```yaml
# talos-machine-config-patch.yaml
machine:
  network:
    extraHostEntries:
      - ip: 127.0.0.1
        aliases:
          - nginx-proxy
  sysctls:
    net.ipv4.ip_forward: "1"
  files:
    - content: |
        #!/bin/bash
        iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 30443
      permissions: 0755
      path: /etc/kubernetes/setup-port-forward.sh
  time:
    servers:
      - time.cloudflare.com
```

Apply the patch:
```bash
talosctl patch machineconfig --patch @talos-machine-config-patch.yaml
```

### Option 3: Install MetalLB LoadBalancer 🔧

Install MetalLB to provide LoadBalancer functionality:

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

# Configure IP pool (adjust for your network)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 192.168.10.200-192.168.10.250  # Adjust for your network
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
```

Then your LoadBalancer service will get an external IP automatically.

### Option 4: Manual iptables Rules (Temporary) ⚠️

**Note**: These rules will be lost on reboot unless made persistent.

```bash
# SSH to your Talos node and run:
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 30443

# Test
curl -k https://192.168.10.176:443/
```

### Option 5: Disable PodSecurity (Not Recommended) ❌

Create a new namespace without PodSecurity restrictions:

```bash
kubectl create namespace nginx-proxy
kubectl label namespace nginx-proxy pod-security.kubernetes.io/enforce=privileged

# Redeploy to nginx-proxy namespace with hostNetwork: true
```

## Recommended Approach 🚀

1. **For immediate use**: Use the current NodePort (30443) - it's working perfectly
2. **For production**: Implement Option 2 (Talos machine config) for clean port 443 access
3. **For advanced setups**: Install MetalLB (Option 3) for proper LoadBalancer support

## Current Working URLs

- **HTTPS**: `https://192.168.10.176:30443`
- **GitLab SSH**: `ssh://192.168.10.176:30223`

## Verification Commands

```bash
# Check deployment status
kubectl get deployments nginx-reverse-proxy
kubectl get pods -l app=nginx-reverse-proxy
kubectl get services -l app=nginx-reverse-proxy

# Test connectivity
curl -k -I https://192.168.10.176:30443/

# Check logs
kubectl logs -l app=nginx-reverse-proxy -f
```

Your nginx reverse proxy is fully functional - the only remaining step is choosing how you want to expose port 443 based on your requirements!