#!/bin/bash
# Generate self-signed certificate for Sentinel

CERT_DIR="$HOME/.sentinel/certs"
mkdir -p "$CERT_DIR"

openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" \
    -days 365 -nodes -subj "/CN=sentinel.local" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

chmod 600 "$CERT_DIR/server.key"
echo "Certificates created in $CERT_DIR"
