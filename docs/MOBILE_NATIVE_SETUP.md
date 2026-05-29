# Mobile native setup (Capacitor)

VoiceMemory’s mobile path is a **Capacitor shell** around the existing Next.js app. Native projects live in `ios/` and `android/`.

## Prerequisites

- Node 20+ (match CI)
- **iOS:** Xcode 15+, CocoaPods or Swift Package Manager (Capacitor 8 uses SPM by default)
- **Android:** Android Studio, JDK 17 recommended (Gradle may fail on JDK 24+)

## Configure server URL

`capacitor.config.ts` sets `server.url` from:

1. `CAPACITOR_SERVER_URL`
2. `NEXT_PUBLIC_APP_URL`
3. Fallback `https://voicememory.app`

Auth and Stripe rely on **cookies and redirects on that origin** — do not point the shell at a different domain than production auth without updating Stripe redirect URLs.

## Workflow

```bash
npm install
npm run mobile:init          # cap sync
npm run mobile:ios           # Xcode
npm run mobile:android       # Android Studio
npm run validate:mobile-native
```

## Permissions

| Capability | iOS | Android |
|------------|-----|---------|
| Microphone (record) | `NSMicrophoneUsageDescription` | `RECORD_AUDIO` |
| Photo attach | `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription` | `READ_MEDIA_IMAGES`, `CAMERA` |
| Push | **Not configured** (no live push provider) | **Not configured** |

## Deep links

- Scheme: `voicememory://`
- Handled in `lib/mobile/capacitor-bootstrap.ts` → navigates WebView to path on loaded origin.
- **Universal Links / App Links** (`https://your.domain/...`) need `apple-app-site-association` and `assetlinks.json` on the server — not shipped yet.

## Stripe on mobile

Checkout opens in the WebView (or system browser if you change flow). App Store IAP is **not** implemented; see `docs/MOBILE_SUBSCRIPTION_STRATEGY.md`.

## Store submission blockers (honest)

- Replace placeholder icons/splash
- Privacy policy URL in store listings
- Test account for reviewers
- Prove account deletion and data export on device
- Decide IAP vs web billing per store policy
- Device QA: mic permission, offline recording draft, cookie persistence
