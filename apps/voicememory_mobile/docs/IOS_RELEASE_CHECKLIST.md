# iOS release checklist — ArchiveMe

See also: **`APP_STORE_SUBMISSION_PACK.md`** (TestFlight + App Store Connect one-pager).

## Identity

- **Display name:** ArchiveMe (`CFBundleDisplayName` in Info.plist)
- **Bundle ID:** `com.voicememory.mobile` (Runner target in Xcode → Signing)
- **Widget extension ID (when enabled):** `com.voicememory.mobile.TodayCheckWidget`
- **App Group:** `group.com.voicememory.mobile`
- **URL schemes:** `archiveme://` (primary widget/deep link), `voicememory://` (legacy compatibility)

## Capabilities

- Microphone: `NSMicrophoneUsageDescription` in Info.plist
- App Transport Security: HTTPS only (`NSAllowsArbitraryLoads` = false)
- No push entitlement for v1

## Signing

1. Open **`ios/Runner.xcworkspace`** (not `Runner.xcodeproj`)
2. Select Runner target → Signing & Capabilities
3. Team + automatic signing for TestFlight
4. Archive: Product → Archive → Distribute

## App Store Connect

- Privacy nutrition labels: voice audio, email (if signed in), device identifiers for capture attest
- No health/diagnosis claims
- Screenshots: Record, Archive (Patterns), Account, Sample Archive

## Purchases (RevenueCat — not ready until setup complete)

- Native IAP via RevenueCat — **not** Stripe / Safari checkout
- Purchases unavailable until App Store Connect banking + RevenueCat products are configured
- Release build must include `REVENUECAT_IOS_API_KEY` when ready (see `docs/REVENUECAT_RELEASE_CHECKLIST.md`)
- Entitlement id: **`pro`**
- Complete sandbox purchase + restore evidence before paid launch

## TestFlight

- [ ] Mic permission prompt on first record
- [ ] Record → transcribe → analyze on production API
- [ ] First save → Archive Home shows cautious next step
- [ ] Sample Archive reachable from Archive Home
- [ ] Restore purchases path reachable (returns unavailable until RC configured)

## Build

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

Add RevenueCat dart-define when billing setup is complete.

See also: `LAUNCH_VALIDATION.md`, `REVENUECAT_LAUNCH_BLOCKERS.md`.
