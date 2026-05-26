# Mobile subscription strategy

VoiceMemory keeps **one entitlement layer** (`lib/entitlement/entitlements.ts`) regardless of how the user pays.

## Web (current path)

- **Provider:** Stripe Checkout + Customer Portal (when wired).
- **Entitlements:** Webhook or client sync calls `setBillingGrantedEntitlements()` and sets plan to `pro`.
- **Mobile browser:** Same Stripe Checkout in Safari/Chrome — avoid embedding checkout in opaque WebViews without cookie support.

## Native wrapper (future)

- **Wrapper:** Capacitor (see `lib/mobile/platform.ts` → `isNativeWrapper()`).
- **App Store / Play:** If store rules require IAP for digital features, add **RevenueCat** (or StoreKit/Google Play Billing) as a **second provider** that maps to the same entitlement IDs:
  - `unlimited_archive`
  - `encrypted_backup`
  - `open_loops`
  - `export_reports`
  - `deeper_resurfacing`

Do **not** fork product logic per store — only the purchase adapter changes.

## Rules

1. Free tier stays fully usable for recording and recent archive.
2. No streak-based or guilt-based paywalls on mobile.
3. Push notifications (when live) are quiet continuity only — not billing reminders.
4. Preview Pro (`setPreviewTier`) remains dev-only until live billing is enabled in `payment-stack.ts`.

## Implementation order

1. Stripe on web → validate entitlements in production.
2. Ship PWA + Capacitor shell with same Next.js origin or bundled static export.
3. Add RevenueCat only if App Store review requires IAP for Pro features.
