#!/bin/sh

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

echo set -gx DOCKER_HOST tcp://192.168.10.10:2375
echo export DOCKER_HOST=tcp://192.168.10.10:2375
echo export DOCKER_HOST=ssh://henninb@192.168.10.10

# doas cp /etc/letsencrypt/live/finance.bhenning.com/privkey.pem finance.bhenning.privkey.pem
# doas cp /etc/letsencrypt/live/finance.bhenning.com/fullchain.pem finance.bhenning.fullchain.pem
# doas chown henninb:henninb *.pem

# Validate certificates before deployment
if ! validate_certificates; then
  log_error "Cannot proceed with deployment due to certificate validation failures."
  exit 1
fi

docker context create remote --docker "host=ssh://henninb@192.168.10.10"
# echo docker context use remote
# docker context ls

docker build -t nginx-reverse-proxy .

# docker save nginx-reverse-proxy | docker --context remote load

# echo export DOCKER_HOST=ssh://henninb@192.168.10.10
# export DOCKER_HOST=tcp://192.168.10.10:2375
# export DOCKER_HOST=ssh://192.168.10.10
docker rm -f nginx-reverse-proxy
docker run --name=nginx-reverse-proxy -h nginx-reverse-proxy --restart unless-stopped -p 443:443 -d nginx-reverse-proxy
#
# docker rm -f nginx-reverse-proxy
docker commit nginx-reverse-proxy nginx-reverse-proxy
docker save nginx-reverse-proxy | docker --context remote load
export DOCKER_HOST=ssh://192.168.10.10
docker rm -f nginx-reverse-proxy
docker run --name=nginx-reverse-proxy -h nginx-reverse-proxy --restart unless-stopped -p 192.168.10.10:443:443 -d nginx-reverse-proxy
docker ps -a

exit 0
