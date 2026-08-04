# RevenueCat release checklist

## Required dart-defines (never commit real keys)

| Define | Platform | Purpose |
|--------|----------|---------|
| `REVENUECAT_IOS_API_KEY` | iOS | App Store builds |
| `REVENUECAT_ANDROID_API_KEY` | Android | Play Store builds |
| `REVENUECAT_API_KEY` | Either | Fallback if platform-specific key unset |

Set at build time only — via CI secrets, Xcode scheme, or `flutter build` `--dart-define`.

## External console checklist (not evidence of completed changes)

- [ ] In RevenueCat, confirm primary entitlement ID: `archive_loop_pro` (legacy `pro` is read-only
  migration compatibility)
- [ ] In RevenueCat, set the intended offering as current; the app reads
  `offerings.current` unless an offering ID is explicitly provided
- [ ] In the store consoles, create the intended monthly and annual products
- [ ] In RevenueCat, link those products to exactly the `monthly` and `annual`
  package types; do not expose a lifetime package
- [ ] Optionally pass `REVENUECAT_MONTHLY_PRODUCT_ID` and
  `REVENUECAT_YEARLY_PRODUCT_ID` to validate identifiers for a release
- [ ] Restore behavior: **Transfer to new App User ID**
- [ ] App Store Connect / Play Console products created and approved
- [ ] Entitlement attached to both products

Completing this file does not claim that RevenueCat, App Store Connect, or Play
Console was changed. Attach external screenshots and physical-device evidence
before marking paid launch ready.

## iOS test purchase steps

1. Build with `REVENUECAT_IOS_API_KEY` set
2. Use Sandbox Apple ID on device
3. Open Settings → Subscription (or in-app paywall)
4. Select plan → purchase
5. Confirm Pro entitlement unlocks pattern features
6. Delete app / reinstall → **Restore Purchases** still works

## Android test purchase steps

1. Build with `REVENUECAT_ANDROID_API_KEY` set
2. Add license testers in Play Console
3. Install internal testing build
4. Open paywall → purchase test subscription
5. Confirm entitlement refresh

## Restore purchase steps

- Paywall → **Restore Purchases**
- Settings → **Restore purchases** (if exposed)
- Expect snackbar / UI update when Pro is active

## If API key is missing

| Mode | Behavior |
|------|----------|
| **Trial** (`ARCHIVEME_TRIAL_MODE=true`) | RevenueCat never initialized; app runs local-only; no crash |
| **Production consumer** | Paywall shows: "Subscription plans are not set up in this build yet." |
| **Debug** | Same as production; logs `RevenueCat: disabled — no API key` |

Trial mode exception: billing is not required. `_initializeForTrial()` does not call `RevenueCatService.initialize()`.

## Production release warning

If a user opens `/subscription` without a configured key:

- Paywall displays `ConsumerUiCopy.paywallBillingNotConfigured`
- Primary purchase button disabled (no packages)
- **Restore Purchases** still available but will no-op gracefully

Fix: rebuild with the correct `--dart-define` before public release.

## Verify configuration (developer unlock)

With developer settings unlocked:

- `/revenuecat-verify` — SDK status screen
- Check configured / offerings / entitlement state

## Build examples

```bash
# iOS release with billing
flutter build ios --release \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx

# Android release with billing
flutter build appbundle --release \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx

# Trial (no RevenueCat required)
flutter run --dart-define=ARCHIVEME_TRIAL_MODE=true
```

## Do not

- Hardcode API keys in source
- Commit keys to git
- Enable trial define in App Store / Play release builds
