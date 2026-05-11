#!/bin/bash

WEBSERVER_IP="10.0.0.2"
PORT="443"
CA_CERT="/opt/ca/ca.crt"

echo "=== Nginx Verification Script ==="
echo "Target: https://${WEBSERVER_IP}:${PORT}"
echo ""

# Check if CA cert exists
if [ ! -f "$CA_CERT" ]; then
  echo "ERROR: CA certificate not found at $CA_CERT"
  exit 1
fi

# Send curl request
RESPONSE=$(curl --cacert "$CA_CERT" \
                --resolve "webserver.lab.local:${PORT}:${WEBSERVER_IP}" \
                --silent \
                --write-out "\nHTTP_STATUS:%{http_code}" \
                "https://webserver.lab.local:${PORT}")

# Split response body and status code
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS")

# Evaluate result
if [ "$HTTP_STATUS" == "200" ]; then
  echo "STATUS: OK (HTTP $HTTP_STATUS)"
  echo "RESPONSE: $BODY"
  exit 0
else
  echo "STATUS: FAILED (HTTP $HTTP_STATUS)"
  echo "Nginx may not be running or the certificate is invalid."
  exit 1
fi