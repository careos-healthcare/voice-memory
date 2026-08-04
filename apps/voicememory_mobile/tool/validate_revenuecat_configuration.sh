#!/usr/bin/env bash
set -euo pipefail

platform=""
mode="paid"
while (($#)); do
  case "$1" in
    --platform) platform="${2:-}"; shift 2 ;;
    --paid) mode="paid"; shift ;;
    --free) mode="free"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 64 ;;
  esac
done

if [[ "$platform" != "ios" && "$platform" != "android" ]]; then
  echo "Usage: $0 --platform ios|android [--paid|--free]" >&2
  exit 64
fi

enabled="${REVENUECAT_PURCHASES_ENABLED:-true}"
if [[ "$mode" == "free" ]]; then
  if [[ "$enabled" != "false" ]]; then
    echo "Free build requires REVENUECAT_PURCHASES_ENABLED=false" >&2
    exit 1
  fi
  echo "RevenueCat configuration valid: purchases explicitly disabled"
  exit 0
fi

if [[ "$enabled" == "false" ]]; then
  echo "Paid build cannot disable purchases" >&2
  exit 1
fi

if [[ "$platform" == "ios" ]]; then
  key="${REVENUECAT_IOS_API_KEY:-}"
  prefix="appl_"
else
  key="${REVENUECAT_ANDROID_API_KEY:-}"
  prefix="goog_"
fi

if [[ -z "$key" ]]; then
  echo "Missing public RevenueCat SDK key for $platform" >&2
  exit 1
fi
if [[ "$key" != "$prefix"* ]]; then
  echo "Malformed public RevenueCat SDK key for $platform" >&2
  exit 1
fi
lower_key="$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')"
if [[ "$key" == sk_* || "$lower_key" == *secret* ]]; then
  echo "RevenueCat secret API keys are forbidden in mobile builds" >&2
  exit 1
fi

entitlement="${REVENUECAT_ENTITLEMENT_ID:-archive_loop_pro}"
monthly="${REVENUECAT_MONTHLY_PRODUCT_ID:-com.voicememory.app.pro.monthly}"
yearly="${REVENUECAT_YEARLY_PRODUCT_ID:-com.voicememory.app.pro.annual}"

[[ "$entitlement" == "archive_loop_pro" ]] || {
  echo "REVENUECAT_ENTITLEMENT_ID must be archive_loop_pro" >&2
  exit 1
}
[[ "$monthly" == "com.voicememory.app.pro.monthly" ]] || {
  echo "Unexpected monthly RevenueCat product identifier" >&2
  exit 1
}
[[ "$yearly" == "com.voicememory.app.pro.annual" ]] || {
  echo "Unexpected yearly RevenueCat product identifier" >&2
  exit 1
}

echo "RevenueCat paid configuration valid for $platform"
echo "  entitlement: archive_loop_pro"
echo "  products: monthly + yearly identifiers validated"
echo "  public SDK key: present and platform-shaped (value redacted)"
