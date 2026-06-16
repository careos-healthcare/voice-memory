# Mobile readiness report

Generated: 2026-05-30T19:55:05.622Z

Overall pillars for store submission — evidence only, no manual checkboxes.

## Product Readiness

**Status:** FAILING

0/4 passing — 0/4 passing · 4 failing

## Store Readiness

**Status:** FAILING

0/5 passing — 0/5 passing · 5 failing

## Distribution Readiness

**Status:** FAILING

0/2 passing — 0/2 passing · 2 failing

## Checklist

### Push notifications

- **Status:** FAILING
- **Evidence:** push_notifications_tested
- structural:push_not_integrated — No push SDK in Flutter app; iOS checklist marks push out of v1
- structural:ios_push_disabled_v1 — Documented: no push entitlement for v1

### Background recording

- **Status:** FAILING
- **Evidence:** background_recording_tested
- structural:background_not_integrated — Recording uses foreground `record` package only — no background audio entitlement evidenced

### Offline mode

- **Status:** FAILING
- **Evidence:** offline_mode_tested
- structural:offline_partial — Local journal store exists; offline_mode_tested evidence still required for store claim

### Sync recovery

- **Status:** FAILING
- **Evidence:** sync_recovery_tested
- structural:sync_recovery_not_evidenced — No sync_recovery_tested evidence on file

### RevenueCat

- **Status:** FAILING
- **Evidence:** revenuecat_store_tested
- structural:revenuecat_absent — RevenueCat not integrated (Stripe browser checkout only)

### Stripe

- **Status:** FAILING
- **Evidence:** stripe_checkout_tested
- structural:stripe_checkout_not_evidenced — No stripe_checkout_tested evidence on file

### Restore purchases

- **Status:** FAILING
- **Evidence:** restore_purchases_tested
- structural:restore_absent — No restore purchases flow in Flutter app — requires IAP + restore_purchases_tested evidence

### iOS signing

- **Status:** FAILING
- **Evidence:** ios_signing_release
- structural:ios_signing_not_evidenced — No ios_signing_release evidence on file

### Android signing

- **Status:** FAILING
- **Evidence:** android_signing_release
- structural:android_release_debug_signing — Android release build still uses debug signing
- structural:android_signing_not_evidenced — No android_signing_release evidence on file

### TestFlight

- **Status:** FAILING
- **Evidence:** testflight_uploaded
- structural:testflight_not_uploaded — No testflight_uploaded evidence on file

### Play Store

- **Status:** FAILING
- **Evidence:** play_internal_uploaded
- structural:play_internal_not_uploaded — No play_internal_uploaded evidence on file

## Summary

- Passing: 0
- Failing: 11
- Unknown: 0

Add proof: `mobile/evidence/<id>.json` — see `mobile/evidence/README.md`.

- Generated 2026-05-30T19:55:05.622Z
- Checklist: 0 passing · 11 failing · 0 unknown
- Evidence files: 0 · Structural signals: 16

- Product Readiness — 0/4 passing · 4 failing
- Store Readiness — 0/5 passing · 5 failing
- Distribution Readiness — 0/2 passing · 2 failing

- Push notifications: FAILING (evidence: push_notifications_tested)
- Background recording: FAILING (evidence: background_recording_tested)
- Offline mode: FAILING (evidence: offline_mode_tested)
- Sync recovery: FAILING (evidence: sync_recovery_tested)
- RevenueCat: FAILING (evidence: revenuecat_store_tested)
- Stripe: FAILING (evidence: stripe_checkout_tested)
- Restore purchases: FAILING (evidence: restore_purchases_tested)
- iOS signing: FAILING (evidence: ios_signing_release)
- Android signing: FAILING (evidence: android_signing_release)
- TestFlight: FAILING (evidence: testflight_uploaded)
- Play Store: FAILING (evidence: play_internal_uploaded)
