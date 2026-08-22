# RevenueCat launch blockers — ArchiveMe mobile

**Purchases are not available for paid launch until RevenueCat and store setup are complete.** This branch does not configure live billing or require IBAN/banking setup.

## Current status

| Item | Status |
|------|--------|
| RevenueCat SDK wired in app | Yes (code) |
| Live API keys in release builds | **Not configured** |
| App Store / Play products linked | **Blocked** (banking / store setup) |
| Sandbox purchase evidence | **Not complete** |
| Restore purchases evidence | **Not complete** |
| Paid launch ready | **No** |

When keys are missing, the paywall shows: *“Purchases are not available right now.”*

## Pro value message (packaging)

- **Core promise:** “Deeper long-term evidence history”
- Pro Preview and archive cards explain what Pro adds later — not a live paywall
- Purchases remain **unavailable** until RevenueCat/store setup and sandbox purchase/restore evidence pass
- Do **not** claim subscriptions can be purchased in App Store metadata until verified

See `lib/features/pro_value/pro_value_copy.dart` for the central copy source.

## Before paid launch

1. Complete App Store Connect / Play Console banking and agreements.
2. Create subscription products and link them in RevenueCat.
3. Build with dart-defines:
   - `REVENUECAT_IOS_API_KEY` (iOS)
   - `REVENUECAT_ANDROID_API_KEY` (Android)
4. Confirm entitlement id is **`pro`** (`RevenueCatService.proEntitlementId`).
5. Complete sandbox **purchase** and **restore** manual tests (`docs/revenuecat_sandbox_manual_test.md`).
6. Verify Pro gates unlock only after real entitlement — not from stale cache.

## Stale Pro cache (fixed in code, must verify)

When RevenueCat is configured and reports **free**, stale cached Pro must **not** win over the store. `BillingService.mergeEntitlements` prefers the store when configured; cache is cleared on free.

**Launch blocker until verified:** run restore + expiry scenarios after live keys are added.

## Not in scope for launch hardening

- IBAN / banking submission
- Live RevenueCat dashboard configuration
- Claiming purchases are ready in App Store copy

See also: `docs/REVENUECAT_RELEASE_CHECKLIST.md`, `REVENUECAT_PRODUCTION_AUDIT.md`.
