# Mobile release evidence

Store readiness is **evidence-only** — no manual checkboxes in the app.

## Add proof

Create a JSON file per proof (or set `MOBILE_EVIDENCE_*` env in CI):

```json
{
  "id": "testflight_uploaded",
  "passed": true,
  "recordedAt": "2026-05-25T12:00:00.000Z",
  "source": "ci",
  "note": "Build 42 uploaded to TestFlight"
}
```

## Commercial readiness v1 (physical device)

Files (default `success: false` until real tests):

- `ios_signing_tested.json`
- `android_signing_tested.json`
- `testflight_tested.json`
- `play_internal_tested.json`
- `revenuecat_store_tested.json` — production purchase journey (see below)
- `restore_purchases_tested.json` — restore after reinstall (see below)

### RevenueCat production verification v1

On a **physical device**, open Flutter **Settings → RevenueCat verification** (`/revenuecat-verify`):

1. Confirm SDK + offerings + product IDs
2. Sandbox purchase → `purchase_completed` + `entitlement_received`
3. Restore → `restore_completed`
4. Export JSON → commit `mobile/evidence/revenuecat_store_tested.json`

```json
{
  "success": true,
  "device": "iPhone15,2",
  "platform": "ios",
  "offering_loaded": true,
  "purchase_completed": true,
  "entitlement_received": true,
  "restore_completed": true,
  "timestamp": "2026-05-31T12:00:00.000Z"
}
```

```bash
npm run validate:revenuecat-production
```

Web founder view: `/internal/revenuecat-verification` · checklist: `/internal/mobile-readiness`

### Restore production verification v1

On a **physical device** with an active sandbox subscription:

1. Purchase (Subscription screen)
2. Delete the app completely
3. Reinstall from TestFlight / Play internal
4. Open **Settings → Restore production verify** (`/restore-production-verify`)
5. Restore purchases → export JSON → commit `restore_purchases_tested.json`

```json
{
  "success": true,
  "device": "iPhone15,2",
  "platform": "ios",
  "timestamp": "2026-05-31T12:00:00.000Z"
}
```

```bash
npm run validate:restore-production
```

Web: `/internal/restore-verification`

### Store distribution verification v1

After physical signing, upload, install, purchase, and restore — commit evidence with all booleans `true` and a real `timestamp` (ISO-8601).

**TestFlight** (`testflight_tested.json`):

```json
{
  "success": true,
  "build_uploaded": true,
  "build_installed": true,
  "onboarding_completed": true,
  "record_completed": true,
  "archive_viewed": true,
  "purchase_completed": true,
  "restore_completed": true,
  "timestamp": "2026-05-31T12:00:00.000Z"
}
```

**Play internal** (`play_internal_tested.json`) — same shape.

**iOS signing** (`ios_signing_tested.json`):

```json
{
  "success": true,
  "archive_build_created": true,
  "uploaded_to_app_store_connect": true,
  "timestamp": "2026-05-31T12:00:00.000Z"
}
```

**Android signing** (`android_signing_tested.json`):

```json
{
  "success": true,
  "signed_aab_created": true,
  "uploaded_to_play_console": true,
  "timestamp": "2026-05-31T12:00:00.000Z"
}
```

```bash
npm run validate:testflight-proof
npm run validate:play-proof
npm run validate:ios-signing
npm run validate:android-signing
```

Web: `/internal/store-readiness` — pillars: Signing, Store Upload, Install, Purchase, Restore (iOS + Android).

### Offline sync production verification v1

Physical device only (not simulator/emulator). Flutter **Settings → Offline sync verify** (`/offline-sync-verify`):

1. Airplane mode ON
2. Record 5 reflections (eligible, non-draft)
3. Lock baseline → force-quit app → reopen → verify
4. Reconnect network → Sync (sign in if needed)
5. Export JSON → commit `offline_sync_tested.json`

```json
{
  "success": true,
  "device": "iPhone15,2",
  "platform": "ios",
  "reflections_recorded_offline": 5,
  "reflections_synced": 5,
  "belief_preserved": true,
  "evidence_preserved": true,
  "timestamp": "2026-05-31T12:00:00.000Z"
}
```

```bash
npm run validate:offline-sync-production
```
- `purchase_journey_tested.json` — all `steps` must be true
- `offline_sync_tested.json` — offline sync production (see below)

```bash
npm run validate:mobile-primary-product
```

`MOBILE_PRIMARY_PLATFORM_VERDICT` is **PRIMARY_PLATFORM** only when structural checks pass and every evidence file is passing.

## Valid IDs (legacy release evidence)

- `testflight_uploaded`
- `play_internal_uploaded`
- `ios_purchase_tested`
- `android_purchase_tested`
- `push_notifications_tested`
- `background_recording_tested`
- `offline_mode_tested`
- `sync_recovery_tested`
- `revenuecat_store_tested`
- `stripe_checkout_tested`
- `restore_purchases_tested`
- `ios_signing_release`
- `android_signing_release`

`npm run validate:mobile-readiness` fails while any checklist row is **UNKNOWN**.

## Native push production v2 (FCM — physical devices only)

File: `native_push_verification.json`

Backend sends real FCM via `POST /api/internal/send-test-push` — **no local notifications**.

Per platform (`ios` and `android`):

- `permission_granted`, `notification_received`, `notification_opened`
- `archive_destination_verified`, `discover_destination_verified`, `record_destination_verified`
- `timestamp`

```bash
npm run validate:push-production
```

Web: `/internal/mobile-push-readiness` — PASSING only when **both** platforms pass.
