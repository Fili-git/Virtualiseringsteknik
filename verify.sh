#!/bin/bash
# =============================================================================
# verify.sh - Verification script for CA and Webservers
# Run from the CA node: bash verify.sh
# =============================================================================

# ---------- Configuration ----------------------------------------------------
CA_CERT="/opt/ca/ca.crt"
WEBSERVERS=("10.0.0.2" "10.0.0.3")
WARN_DAYS=30

# ---------- Colors -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- Helper functions -------------------------------------------------
pass() { echo -e "  ${GREEN}[OK]${NC}  $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "  ${BLUE}[INFO]${NC} $1"; }
header() {
  echo ""
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo -e "${BOLD}  $1${NC}"
  echo -e "${BOLD}════════════════════════════════════════${NC}"
}

# ---------- Check dependencies -----------------------------------------------
check_deps() {
  header "Checking dependencies"
  for cmd in curl openssl; do
    if command -v "$cmd" &>/dev/null; then
      pass "$cmd is installed"
    else
      fail "$cmd is missing – install with: apt-get install -y $cmd"
      exit 1
    fi
  done
}

# ---------- Check CA certificate locally -------------------------------------
check_ca_cert() {
  header "CA Certificate (local)"

  if [[ ! -f "$CA_CERT" ]]; then
    fail "CA certificate not found: $CA_CERT"
    return
  fi
  pass "CA certificate found: $CA_CERT"

  SUBJECT=$(openssl x509 -in "$CA_CERT" -noout -subject 2>/dev/null | sed 's/subject=//')
  ISSUER=$(openssl x509  -in "$CA_CERT" -noout -issuer  2>/dev/null | sed 's/issuer=//')
  info "Subject : $SUBJECT"
  info "Issuer  : $ISSUER"

  FP=$(openssl x509 -in "$CA_CERT" -noout -fingerprint -sha256 2>/dev/null | sed 's/SHA256 Fingerprint=//')
  info "SHA-256 : $FP"

  NOT_AFTER=$(openssl x509 -in "$CA_CERT" -noout -enddate 2>/dev/null | cut -d= -f2)
  info "Valid until: $NOT_AFTER"

  EXPIRE_EPOCH=$(date -d "$NOT_AFTER" +%s 2>/dev/null)
  NOW_EPOCH=$(date +%s)
  DAYS_LEFT=$(( (EXPIRE_EPOCH - NOW_EPOCH) / 86400 ))

  if (( DAYS_LEFT < 0 )); then
    fail "CA certificate has EXPIRED ($DAYS_LEFT days ago)"
  elif (( DAYS_LEFT < WARN_DAYS )); then
    warn "CA certificate expires in $DAYS_LEFT days!"
  else
    pass "CA certificate is valid ($DAYS_LEFT days remaining)"
  fi
}

# ---------- Verify a single webserver ----------------------------------------
verify_webserver() {
  local IP="$1"

  header "Webserver: $IP"

  # ------------------------------------------------------------------
  # 1. HTTPS connection with CA verification + response body
  # ------------------------------------------------------------------
  echo -e "\n${BOLD}[1] HTTPS connection with CA verification${NC}"

  HTTP_RESPONSE=$(curl --silent \
                       --cacert "$CA_CERT" \
                       --write-out "\n%{http_code}" \
                       "https://$IP" 2>/dev/null)

  HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)
  HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n 1)

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "HTTPS connection succeeded with CA verification"
  else
    fail "HTTPS connection failed (code: $HTTP_CODE)"
  fi

  # ------------------------------------------------------------------
  # 2. HTTP status code
  # ------------------------------------------------------------------
  echo -e "\n${BOLD}[2] HTTP status code${NC}"
  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "HTTP status code: $HTTP_CODE (expected: 200)"
  else
    fail "HTTP status code: $HTTP_CODE (expected 200)"
  fi

  if [[ -n "$HTTP_BODY" ]]; then
    info "Response body: $(echo "$HTTP_BODY" | tr -d '\n' | cut -c1-80)"
  fi

  # Fetch certificate data once and reuse
  RAW_CERT=$(echo | openssl s_client \
    -connect "$IP:443" \
    -CAfile "$CA_CERT" \
    -servername "$IP" 2>/dev/null)

  # ------------------------------------------------------------------
  # 3. Certificate details (subject, issuer, fingerprint)
  # ------------------------------------------------------------------
  echo -e "\n${BOLD}[3] Certificate details${NC}"

  CERT_TEXT=$(echo "$RAW_CERT" \
    | openssl x509 -noout -subject -issuer -fingerprint -sha256 2>/dev/null)

  if [[ -n "$CERT_TEXT" ]]; then
    CERT_SUBJECT=$(echo "$CERT_TEXT" | grep 'subject=' | sed 's/subject=//')
    CERT_ISSUER=$(echo "$CERT_TEXT"  | grep 'issuer='  | sed 's/issuer=//')
    CERT_FP=$(echo "$CERT_TEXT"      | grep 'SHA256'   | sed 's/SHA256 Fingerprint=//')
    pass "Certificate received from server"
    info "Subject : $CERT_SUBJECT"
    info "Issuer  : $CERT_ISSUER"
    info "SHA-256 : $CERT_FP"
  else
    fail "Could not retrieve certificate from $IP:443"
  fi

  # ------------------------------------------------------------------
  # 4. Verify certificate is signed by your CA
  # ------------------------------------------------------------------
  echo -e "\n${BOLD}[4] Verification – signed by your CA${NC}"

  VERIFY_RESULT=$(echo "$RAW_CERT" | grep -E "Verify return code")
  if echo "$VERIFY_RESULT" | grep -q "0 (ok)"; then
    pass "Certificate is correctly signed by your CA"
    info "$VERIFY_RESULT"
  else
    fail "Certificate verification failed"
    info "$VERIFY_RESULT"
  fi

  # ------------------------------------------------------------------
  # 5. Expiry date + warning if <30 days remaining
  # ------------------------------------------------------------------
  echo -e "\n${BOLD}[5] Certificate expiry date${NC}"

  CERT_ENDDATE=$(echo "$RAW_CERT" \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

  if [[ -z "$CERT_ENDDATE" ]]; then
    fail "Could not read expiry date"
    return
  fi

  info "Valid until: $CERT_ENDDATE"

  EXPIRE_EPOCH=$(date -d "$CERT_ENDDATE" +%s 2>/dev/null)
  NOW_EPOCH=$(date +%s)
  DAYS_LEFT=$(( (EXPIRE_EPOCH - NOW_EPOCH) / 86400 ))

  if (( DAYS_LEFT < 0 )); then
    fail "Certificate has EXPIRED!"
  elif (( DAYS_LEFT < WARN_DAYS )); then
    warn "Certificate expires in $DAYS_LEFT days – renew soon!"
  else
    pass "Certificate is valid ($DAYS_LEFT days remaining)"
  fi
}

# ---------- Summary ----------------------------------------------------------
summary() {
  header "Verification complete"
  echo -e "  Webservers checked : ${WEBSERVERS[*]}"
  echo -e "  CA certificate used: $CA_CERT"
  echo ""
}

# ---------- Main -------------------------------------------------------------
check_deps
check_ca_cert

for IP in "${WEBSERVERS[@]}"; do
  verify_webserver "$IP"
done

summary
