#!/usr/bin/env bash
# Verify thoughtprint.xyz marketing + email cutover (DNS/Vercel/Resend must be done externally).
set -euo pipefail

MARKETING_URL="${THOUGHTPRINT_MARKETING_URL:-https://thoughtprint.xyz}"
LEGACY_URLS=("https://archiveme.app" "https://voicememory.app")
API_URL="${VOICEMEMORY_APP_URL:-https://voice-memory-api.vercel.app}"
CONTACT_EMAIL="hello@thoughtprint.xyz"

failures=0

echo "== Marketing site ($MARKETING_URL) =="
if curl -fsS -o /dev/null "$MARKETING_URL"; then
  echo "OK  homepage responds"
else
  echo "FAIL homepage"
  failures=$((failures + 1))
fi

if curl -fsS -o /dev/null "$MARKETING_URL/privacy"; then
  echo "OK  privacy page"
else
  echo "FAIL privacy page"
  failures=$((failures + 1))
fi

if curl -fsS "$MARKETING_URL/contact" | grep -q "$CONTACT_EMAIL"; then
  echo "OK  contact page lists $CONTACT_EMAIL"
else
  echo "FAIL contact page missing $CONTACT_EMAIL"
  failures=$((failures + 1))
fi

echo ""
echo "== Legacy redirects (archiveme.app, voicememory.app → thoughtprint.xyz) =="
for legacy_url in "${LEGACY_URLS[@]}"; do
  legacy_location=$(curl -sS -o /dev/null -w "%{redirect_url}" "$legacy_url/privacy" 2>/dev/null || true)
  if [[ "$legacy_location" == *"thoughtprint.xyz/privacy"* ]]; then
    echo "OK  $legacy_url redirects to thoughtprint.xyz"
  else
    echo "FAIL $legacy_url redirect (got: ${legacy_location:-none})"
    failures=$((failures + 1))
  fi
done

echo ""
echo "== Auth email env ($API_URL) =="
if ENV_JSON=$(curl -fsS "$API_URL/api/debug/auth-env" 2>/dev/null); then
  echo "$ENV_JSON" | python3 -m json.tool 2>/dev/null || echo "$ENV_JSON"
  if command -v jq >/dev/null 2>&1; then
    if echo "$ENV_JSON" | jq -e '.resendConfigured == true' >/dev/null; then
      echo "OK  Resend configured"
    else
      echo "FAIL Resend not configured"
      failures=$((failures + 1))
    fi
    if echo "$ENV_JSON" | jq -e '.emailFromDomain == "thoughtprint.xyz"' >/dev/null; then
      echo "OK  EMAIL_FROM on thoughtprint.xyz"
    else
      echo "FAIL EMAIL_FROM not on thoughtprint.xyz"
      failures=$((failures + 1))
    fi
    if echo "$ENV_JSON" | jq -e '.productionEmailReady == true' >/dev/null; then
      echo "OK  productionEmailReady"
    else
      echo "FAIL productionEmailReady"
      failures=$((failures + 1))
    fi
  fi
else
  echo "SKIP auth-env (API unreachable — set VOICEMEMORY_APP_URL)"
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "All automated checks passed."
  exit 0
fi
echo "$failures check(s) failed — see docs/product/ARCHIVEME_APP_DNS.md"
exit 1
