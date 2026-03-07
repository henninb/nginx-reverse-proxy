#!/bin/sh

REMOTE_HOST="debian-dockerserver"
REMOTE_USER="henninb"
REMOTE_DIR="/home/${REMOTE_USER}/nginx-reverse-proxy"
IMAGE_NAME="nginx-reverse-proxy"
CONTAINER_NAME="nginx-reverse-proxy"

log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $*"
}

log_error() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - ERROR: $*" >&2
}

# Function to validate certificate and key match
validate_cert_key_match() {
  local cert_path="$1"
  local key_path="$2"
  local pair_name="$3"

  if [ ! -f "$cert_path" ]; then
    log_error "Certificate not found: $cert_path"
    return 1
  fi

  if [ ! -f "$key_path" ]; then
    log_error "Private key not found: $key_path"
    return 1
  fi

  log "Validating $pair_name certificate and private key match..."

  # Check certificate expiration (not expired and not expiring within 24 hours)
  if ! openssl x509 -in "$cert_path" -noout -checkend 86400 >/dev/null 2>&1; then
    log_error "$pair_name certificate is expired or will expire within 24 hours!"
    local cert_expiry
    cert_expiry=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "unknown")
    log_error "Certificate expires: $cert_expiry"
    return 1
  fi

  # Generate hashes to compare certificate and key
  local cert_hash
  local key_hash
  cert_hash=$(openssl x509 -in "$cert_path" -noout -pubkey 2>/dev/null | openssl sha256 2>/dev/null)
  key_hash=$(openssl pkey -in "$key_path" -pubout 2>/dev/null | openssl sha256 2>/dev/null)

  if [ -z "$cert_hash" ] || [ -z "$key_hash" ]; then
    log_error "Failed to generate hashes for $pair_name certificate/key validation"
    return 1
  fi

  if [ "$cert_hash" != "$key_hash" ]; then
    log_error "$pair_name certificate and private key do not match!"
    return 1
  fi

  local cert_expiry
  cert_expiry=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)
  log "✓ $pair_name certificate is valid until: $cert_expiry"
  log "✓ $pair_name certificate and private key match"
  return 0
}

# Validate certificates before deployment
validate_certificates() {
  log "=== Certificate Validation ==="

  local validation_failed=0

  # Validate brianhenning certificate pair
  if ! validate_cert_key_match "brianhenning.fullchain.pem" "brianhenning.privkey.pem" "brianhenning"; then
    validation_failed=1
  fi

  # Validate bhenning certificate pair
  if ! validate_cert_key_match "bhenning.fullchain.pem" "bhenning.privkey.pem" "bhenning"; then
    validation_failed=1
  fi

  if [ $validation_failed -eq 0 ]; then
    log "✓ All certificate validations passed - ready for deployment"
    return 0
  else
    log_error "Certificate validation failed! Fix issues before deployment."
    return 1
  fi
}

# Check nginx Podman image version on remote server
check_nginx_podman_version() {
  log "=== Nginx Podman Image Version Check (Remote Server) ==="

  # Get current nginx image ID if it exists
  local current_image_id
  current_image_id=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "podman images nginx:alpine --format '{{.ID}}' 2>/dev/null | head -1")

  if [ -n "$current_image_id" ]; then
    local current_version
    current_version=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "podman run --rm nginx:alpine nginx -v 2>&1 | grep -o 'nginx/[0-9.]*' | cut -d'/' -f2")
    log "Current remote nginx version: $current_version (Image: $current_image_id)"
  else
    log "No nginx:alpine image found on remote server"
  fi

  # Pull latest nginx image
  log "Pulling latest nginx image on remote server..."
  if ! ssh "${REMOTE_USER}@${REMOTE_HOST}" "podman pull nginx:alpine"; then
    log_error "Failed to pull nginx:alpine on remote server"
    return 1
  fi

  # Get new image info
  local new_image_id
  new_image_id=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "podman images nginx:alpine --format '{{.ID}}' 2>/dev/null | head -1")

  local new_version
  new_version=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "podman run --rm nginx:alpine nginx -v 2>&1 | grep -o 'nginx/[0-9.]*' | cut -d'/' -f2")

  log "Latest nginx version: $new_version (Image: $new_image_id)"

  if [ -n "$current_image_id" ] && [ "$current_image_id" = "$new_image_id" ]; then
    log "✓ Already using latest nginx version: $new_version"
  elif [ -n "$current_image_id" ]; then
    log "✓ Updated nginx from $current_version to $new_version"
  else
    log "✓ Downloaded nginx version: $new_version"
  fi

  return 0
}

# Validate certificates before deployment
if ! validate_certificates; then
  log_error "Cannot proceed with deployment due to certificate validation failures."
  exit 1
fi

# Check nginx Podman image version
if ! check_nginx_podman_version; then
  log_error "Failed to check nginx Podman image version."
  exit 1
fi

# Sync project files to remote host
log "=== Syncing project files to ${REMOTE_HOST}:${REMOTE_DIR} ==="
ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"
rsync -av --exclude='.git' --exclude='k8s/' ./ "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"

# Build and run on remote host
log "=== Building and deploying container on ${REMOTE_HOST} ==="
ssh -T "${REMOTE_USER}@${REMOTE_HOST}" REMOTE_DIR="${REMOTE_DIR}" IMAGE_NAME="${IMAGE_NAME}" CONTAINER_NAME="${CONTAINER_NAME}" 'bash -s' << 'ENDSSH'
set -e

cd "${REMOTE_DIR}"

echo "Removing existing container..."
podman rm -f "${CONTAINER_NAME}" 2>/dev/null || true

echo "Removing old image..."
podman rmi "${IMAGE_NAME}" 2>/dev/null || true

echo "Building new image..."
podman build -t "${IMAGE_NAME}" .

# Allow rootless Podman to bind privileged ports (443).
# This sysctl is set at runtime but resets on reboot.
# To make it permanent on debian-dockerserver, run once:
#   echo "net.ipv4.ip_unprivileged_port_start=443" | sudo tee /etc/sysctl.d/99-podman-ports.conf
echo "Allowing rootless Podman to bind privileged ports..."
echo "NOTE: To make this permanent, run: echo \"net.ipv4.ip_unprivileged_port_start=443\" | sudo tee /etc/sysctl.d/99-podman-ports.conf"
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=443

echo "Starting container..."
podman run \
  --name="${CONTAINER_NAME}" \
  --hostname="${CONTAINER_NAME}" \
  --network=host \
  -d \
  "${IMAGE_NAME}"

podman ps -a

echo "Writing systemd Quadlet for auto-start on boot..."
mkdir -p ~/.config/containers/systemd
cat > ~/.config/containers/systemd/${CONTAINER_NAME}.container << EOF
[Unit]
Description=Nginx Reverse Proxy
After=network-online.target

[Container]
Image=localhost/${IMAGE_NAME}
ContainerName=${CONTAINER_NAME}
HostName=${CONTAINER_NAME}
Network=host

[Service]
Restart=always
TimeoutStartSec=60

[Install]
WantedBy=default.target
EOF

# Reload user systemd instance if accessible (not available in non-login SSH sessions)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}
systemctl --user daemon-reload 2>/dev/null || true

echo "Quadlet written to ~/.config/containers/systemd/${CONTAINER_NAME}.container"
echo "NOTE: Run 'sudo loginctl enable-linger ${USER}' on this host to enable auto-start on reboot."

echo "Cleaning up build directory..."
rm -rf "${REMOTE_DIR}"
ENDSSH

exit 0
