# iOS release checklist — ArchiveMe

## Identity

- **Display name:** ArchiveMe (`CFBundleDisplayName` in Info.plist)
- **Bundle ID:** `com.voicememory.app` (set in Xcode → Runner → Signing)
- **URL scheme:** `voicememory://` (checkout/auth return — optional)

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
- Screenshots: Record, Memory, Discover, Pattern review, Account

## Stripe checkout

- Pro upgrade opens Stripe Checkout in Safari / ASWebAuthenticationSession via `url_launcher`
- Success/cancel URLs point to web `/pricing` — user returns to app manually

## TestFlight

- [ ] Mic permission prompt on first record
- [ ] Record → transcribe → analyze on production API
- [ ] Sign in with email code
- [ ] Sync journal
- [ ] Blind spot at 5+ reflections
- [ ] Discover second visit paywall (if free tier)

## Build

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```
