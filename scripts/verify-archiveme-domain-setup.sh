#!/usr/bin/env bash
# Verify thoughtprint.xyz marketing + email cutover.
#
# Scope: public, unauthenticated checks only.
#   - archiveme.app / voicememory.app are NOT owned by this project and can
#     never redirect here — don't check them.
#   - /api/internal/auth-env is founder-gated (FOUNDER_MODE + token/session);
#     a plain curl always 404s by design. Check it manually, signed in as a
#     founder, if you need to re-verify EMAIL_FROM/Resend config.
set -euo pipefail

MARKETING_URL="${THOUGHTPRINT_MARKETING_URL:-https://thoughtprint.xyz}"
CONTACT_EMAIL="hello@thoughtprint.xyz"

failures=0

echo "== Marketing site ($MARKETING_URL) =="
if curl -fsSL -o /dev/null "$MARKETING_URL"; then
  echo "OK  homepage responds"
else
  echo "FAIL homepage"
  failures=$((failures + 1))
fi

if curl -fsSL -o /dev/null "$MARKETING_URL/privacy"; then
  echo "OK  privacy page"
else
  echo "FAIL privacy page"
  failures=$((failures + 1))
fi

if curl -fsSL "$MARKETING_URL/contact" | grep -q "$CONTACT_EMAIL"; then
  echo "OK  contact page lists $CONTACT_EMAIL"
else
  echo "FAIL contact page missing $CONTACT_EMAIL"
  failures=$((failures + 1))
fi

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "All automated checks passed."
  exit 0
fi
echo "$failures check(s) failed — see docs/product/ARCHIVEME_APP_DNS.md"
exit 1
