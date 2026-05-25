#!/usr/bin/env bash
# Verify production auth email env + optional send-code test.
# Usage:
#   ./scripts/verify-production-auth-email.sh
#   ./scripts/verify-production-auth-email.sh you@example.com

set -euo pipefail

BASE_URL="${VOICEMEMORY_APP_URL:-https://voice-memory-iota.vercel.app}"

echo "== auth-env =="
ENV_JSON=$(curl -sS "${BASE_URL}/api/debug/auth-env")
echo "$ENV_JSON" | python3 -m json.tool 2>/dev/null || echo "$ENV_JSON"

if command -v jq >/dev/null 2>&1; then
  if ! echo "$ENV_JSON" | jq -e '.resendConfigured and .emailFromConfigured and .appUrlConfigured' >/dev/null; then
    echo "FAIL: missing RESEND_API_KEY, EMAIL_FROM, or NEXT_PUBLIC_APP_URL in Production"
    exit 1
  fi
  if echo "$ENV_JSON" | jq -e '.emailFromUsesResendSandbox == true' >/dev/null 2>&1; then
    echo "FAIL: EMAIL_FROM still uses Resend sandbox (onboarding@resend.dev)."
    echo "Verify a domain at https://resend.com/domains then set:"
    echo "  VoiceMemory <noreply@YOUR_VERIFIED_DOMAIN>"
    exit 1
  fi
  if echo "$ENV_JSON" | jq -e '.productionEmailReady == true' >/dev/null 2>&1; then
    echo "OK: productionEmailReady"
  fi
fi

if [[ -n "${1:-}" ]]; then
  echo ""
  echo "== send-code ($1) =="
  SEND_JSON=$(curl -sS -X POST "${BASE_URL}/api/auth/send-code" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\"}")
  echo "$SEND_JSON" | python3 -m json.tool 2>/dev/null || echo "$SEND_JSON"
  if command -v jq >/dev/null 2>&1; then
    echo "$SEND_JSON" | jq -e '.ok == true' >/dev/null || {
      echo "FAIL: send-code did not return ok:true"
      exit 1
    }
  fi
  echo "OK: check inbox for OTP, then sign in at ${BASE_URL}/account"
fi
