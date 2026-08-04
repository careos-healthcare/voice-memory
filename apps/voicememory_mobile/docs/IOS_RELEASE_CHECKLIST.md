# iOS release checklist — ArchiveMe

See also: **`APP_STORE_SUBMISSION_PACK.md`** (TestFlight + App Store Connect one-pager).

## Identity

- **Display name:** ArchiveMe (`CFBundleDisplayName` in `Info-Release.plist`)
- **Bundle ID:** `com.voicememory.mobile` (Runner target in Xcode → Signing)
- **V1 URL scheme:** `archiveme://`
- **Embedded extensions:** none
- **Explicit Release entitlements:** none

## Capabilities

- Microphone: `NSMicrophoneUsageDescription` in `Info-Release.plist`
- Face ID: `NSFaceIDUsageDescription` only for the optional private lock
- App Transport Security: HTTPS only (`NSAllowsArbitraryLoads` = false)
- No push, app-group, iCloud, HealthKit or background entitlement for V1

## Signing

1. Open **`ios/Runner.xcworkspace`** (not `Runner.xcodeproj`)
2. Select Runner target → Signing & Capabilities
3. Team + automatic signing for TestFlight
4. Archive: Product → Archive → Distribute

## App Store Connect

- Privacy nutrition labels: voice audio, email (if signed in), device identifiers for capture attest
- No health/diagnosis claims
- Screenshots: Record post-save receipt, Archive originals, chronological
  Changes, and Account

## Purchases (RevenueCat — not ready until setup complete)

- Native IAP via RevenueCat — **not** Stripe / Safari checkout
- Purchases unavailable until App Store Connect banking + RevenueCat products are configured
- Release build must include `REVENUECAT_IOS_API_KEY` when ready (see `docs/REVENUECAT_RELEASE_CHECKLIST.md`)
- Entitlement id: **`pro`**
- Complete sandbox purchase + restore evidence before paid launch

## TestFlight

Manual QA script: [TESTFLIGHT_MANUAL_QA.md](./TESTFLIGHT_MANUAL_QA.md)

Access protection audit: [ACCESS_PROTECTION_AUDIT.md](./ACCESS_PROTECTION_AUDIT.md)

- [ ] Mic permission prompt on first record
- [ ] Record → transcribe → analyze on production API
- [ ] First save shows Saved → editable transcript → at most one validated
  observation → exact evidence → correction controls → one next action
- [ ] Second related save can show a distinct Then/Now comparison in Changes
- [ ] Changes evidence opens both exact source moments
- [ ] No graph, analyst, blind-spot, reminder, streak, or paywall card appears
  in the post-save stack
- [ ] Restore purchases path reachable (returns unavailable until RC configured)

## Build

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
bash tool/audit_v1_permissions.sh --ios-only \
  --ios-app build/ios/iphoneos/Runner.app \
  --ios-entitlements ios/Runner/Runner-Release.entitlements
```

Add RevenueCat dart-define when billing setup is complete.

See also: `LAUNCH_VALIDATION.md`, `REVENUECAT_LAUNCH_BLOCKERS.md`.
