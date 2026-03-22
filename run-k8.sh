#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# run-k8.sh — Build and deploy nginx-reverse-proxy to Kubernetes
# -----------------------------------------------------------------------------
# Prerequisites:
#   - kubectl configured and pointing at your cluster
#   - SSH access to both cluster nodes (debian-k8s-cp-01, debian-k8s-worker-02)
#   - Docker or Podman available for building the image
#   - Certificate files present in the project root:
#       bhenning.fullchain.pem   bhenning.privkey.pem
#       brianhenning.fullchain.pem  brianhenning.privkey.pem
#
# Deployment strategy:
#   - Custom image with certs baked in (via Dockerfile)
#   - nginx.conf mounted as a ConfigMap (update config without image rebuild)
#   - hostNetwork: true so nginx binds port 443 directly on the node IP
#   - Pod pinned to debian-k8s-worker-02
# -----------------------------------------------------------------------------

APP_NAME="nginx-reverse-proxy"
NAMESPACE="default"
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
IMAGE="${APP_NAME}:${IMAGE_TAG}"
WORKER_NODE="debian-k8s-worker-01"
CP_NODE="debian-k8s-cp-01"

# --- helpers -----------------------------------------------------------------

info() { echo "[INFO]  $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

require_cmd() { command -v "$1" &>/dev/null || die "'$1' is required but not found in PATH"; }

# --- preflight ---------------------------------------------------------------

require_cmd kubectl

command -v docker &>/dev/null || command -v podman &>/dev/null \
  || die "docker or podman is required"

[[ -f "nginx.conf"                ]] || die "Missing nginx.conf"
[[ -f "bhenning.fullchain.pem"    ]] || die "Missing bhenning.fullchain.pem"
[[ -f "bhenning.privkey.pem"      ]] || die "Missing bhenning.privkey.pem"
[[ -f "brianhenning.fullchain.pem" ]] || die "Missing brianhenning.fullchain.pem"
[[ -f "brianhenning.privkey.pem"  ]] || die "Missing brianhenning.privkey.pem"

# --- build image -------------------------------------------------------------

info "Building Docker image: $IMAGE (tag: $IMAGE_TAG)"
if command -v docker &>/dev/null; then
    docker build -t "$IMAGE" .
else
    podman build -t "$IMAGE" .
fi

# Load image into the cluster nodes via containerd (no registry needed).
info "Importing image into cluster nodes via containerd"
if command -v docker &>/dev/null; then
    docker save "$IMAGE" | ssh "$CP_NODE"    "sudo ctr -n k8s.io images import -"
    docker save "$IMAGE" | ssh "$WORKER_NODE" "sudo ctr -n k8s.io images import -"
else
    podman save "$IMAGE" | ssh "$CP_NODE"    "sudo ctr -n k8s.io images import -"
    podman save "$IMAGE" | ssh "$WORKER_NODE" "sudo ctr -n k8s.io images import -"
fi

# --- apply ConfigMap (nginx.conf) --------------------------------------------
# Uses --from-file so nginx.conf dollar-sign variables are not shell-interpolated.

info "Applying nginx.conf ConfigMap..."
kubectl create configmap nginx-config \
    --from-file=nginx.conf=./nginx.conf \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# --- apply manifests ---------------------------------------------------------

info "Applying Kubernetes manifests to namespace: $NAMESPACE"

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_NAME
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      nodeSelector:
        kubernetes.io/hostname: $WORKER_NODE
      tolerations:
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101
      containers:
        - name: $APP_NAME
          image: $IMAGE
          imagePullPolicy: Never
          command: ["nginx"]
          args: ["-g", "daemon off;"]
          ports:
            - containerPort: 443
              name: https
              protocol: TCP
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
          securityContext:
            allowPrivilegeEscalation: false
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "200m"
              memory: "256Mi"
          livenessProbe:
            tcpSocket:
              port: 443
            initialDelaySeconds: 10
            periodSeconds: 30
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            tcpSocket:
              port: 443
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 5
      volumes:
        - name: nginx-config
          configMap:
            name: nginx-config

---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
spec:
  selector:
    app: $APP_NAME
  ports:
    - name: https
      port: 443
      targetPort: 443
      protocol: TCP
  type: ClusterIP
EOF

# --- force rollout -----------------------------------------------------------

info "Restarting deployment to pick up new image (${IMAGE})..."
kubectl rollout restart deployment/"$APP_NAME" -n "$NAMESPACE"

# --- wait for rollout --------------------------------------------------------

info "Waiting for rollout to complete..."
kubectl rollout status deployment/"$APP_NAME" -n "$NAMESPACE" --timeout=120s

info "Deployment complete. Pod status:"
kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" -o wide

info ""
info "To view logs:     kubectl logs -n $NAMESPACE -l app=$APP_NAME -f"
info "Node IP (port 443 is live on): ssh $WORKER_NODE hostname -I"
