#!/bin/bash
set -e

# Zipsa Demo Health Check Script
# Usage: ./health-check.sh [base_url]

BASE_URL="${1:-http://localhost}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

CHECKS_PASSED=0
CHECKS_FAILED=0

check() {
    local name="$1"
    local result="$2"

    if [ "$result" = "true" ]; then
        log_pass "$name"
        ((CHECKS_PASSED++))
    else
        log_fail "$name"
        ((CHECKS_FAILED++))
    fi
}

echo "Zipsa Demo Health Check"
echo "======================="
echo "Target: $BASE_URL"
echo ""

# Check 1: Health endpoint
echo "Checking health endpoint..."
if curl -sf "${BASE_URL}/health" > /dev/null 2>&1; then
    check "Health endpoint responds" "true"
else
    check "Health endpoint responds" "false"
fi

# Check 2: API root
echo "Checking API root..."
RESPONSE=$(curl -sf "${BASE_URL}/" 2>&1 || echo "FAILED")
if [ "$RESPONSE" != "FAILED" ]; then
    check "API root accessible" "true"
else
    check "API root accessible" "false"
fi

# Check 3: Monitor endpoint (should require auth)
echo "Checking monitor authentication..."
HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "${BASE_URL}/monitor" 2>&1 || echo "000")
if [ "$HTTP_CODE" = "401" ]; then
    check "Monitor requires authentication" "true"
elif [ "$HTTP_CODE" = "200" ]; then
    log_warn "Monitor is accessible without authentication!"
    check "Monitor requires authentication" "false"
else
    check "Monitor endpoint reachable" "false"
fi

# Check 4: Monitor with auth (if token provided)
if [ -n "$ADMIN_TOKEN" ]; then
    echo "Checking monitor with authentication..."
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE_URL}/monitor" 2>&1 || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        check "Monitor accessible with valid token" "true"
    else
        check "Monitor accessible with valid token" "false"
    fi
else
    log_warn "ADMIN_TOKEN not set - skipping authenticated monitor check"
fi

# Check 5: OpenAI-compatible endpoint
echo "Checking OpenAI-compatible API..."
RESPONSE=$(curl -sf -X POST "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"test","messages":[]}' 2>&1 || echo "FAILED")

# We expect some response (even an error) from the API
if [ "$RESPONSE" != "FAILED" ]; then
    check "OpenAI-compatible endpoint responds" "true"
else
    check "OpenAI-compatible endpoint responds" "false"
fi

# Check 6: SSL certificate (if HTTPS)
if [[ "$BASE_URL" == https://* ]]; then
    echo "Checking SSL certificate..."
    DOMAIN=$(echo "$BASE_URL" | sed 's|https://||' | cut -d'/' -f1)
    CERT_EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)

    if [ -n "$CERT_EXPIRY" ]; then
        EXPIRY_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$CERT_EXPIRY" +%s 2>/dev/null || date -d "$CERT_EXPIRY" +%s 2>/dev/null)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

        if [ "$DAYS_LEFT" -gt 7 ]; then
            check "SSL certificate valid (${DAYS_LEFT} days left)" "true"
        else
            log_warn "SSL certificate expires in ${DAYS_LEFT} days!"
            check "SSL certificate valid" "false"
        fi
    else
        check "SSL certificate readable" "false"
    fi
fi

# Summary
echo ""
echo "======================="
echo "Results: ${CHECKS_PASSED} passed, ${CHECKS_FAILED} failed"

if [ "$CHECKS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed.${NC}"
    exit 1
fi
