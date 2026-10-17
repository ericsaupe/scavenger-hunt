#!/usr/bin/env bash
set -euo pipefail

ca=/caddy/caddy/pki/authorities/local/root.crt
for _ in $(seq 1 120); do
  [ -f "$ca" ] && break
  sleep 1
done
if [ -f "$ca" ]; then
  cat /etc/ssl/certs/ca-certificates.crt "$ca" > /tmp/ca-bundle.crt
  export SSL_CERT_FILE=/tmp/ca-bundle.crt
else
  echo "Caddy root certificate never appeared at $ca" >&2
fi

exec "$@"
