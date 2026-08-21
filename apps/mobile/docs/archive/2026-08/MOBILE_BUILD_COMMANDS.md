# Mobile build commands

From repo root:

```bash
cd apps/mobile
flutter clean
flutter pub get
flutter analyze
flutter test
```

## API base URL (required for release)

```bash
export API=https://voice-memory-iota.vercel.app
```

### Android release bundle

```bash
flutter build appbundle --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=$API
```

### iOS release (then archive in Xcode)

```bash
flutter build ios --release \
  --dart-define=VOICE_MEMORY_API_BASE_URL=$API
```

Open **`ios/Runner.xcworkspace`** — not `Runner.xcodeproj`.

### Local dev

```bash
# iOS simulator
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://127.0.0.1:3000

# Android emulator
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://10.0.2.2:3000
```

Never ship a store build with localhost unless intentional.

## RevenueCat (native billing — no browser checkout)

```bash
flutter run \
  --dart-define=VOICE_MEMORY_API_BASE_URL=$API \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx \
  --dart-define=REVENUECAT_COACH_SEAT_PRODUCT_ID=professional_coach_per_seat \
  --dart-define=REVENUECAT_COACH_SEAT_ENTITLEMENT_ID=professional_coach_per_seat
```

### RevenueCat coach seat (professional dashboard)

In the RevenueCat dashboard:

1. Create entitlement **`professional_coach_per_seat`**
2. Create App Store / Play product (e.g. `professional_coach_per_seat`) and attach to that entitlement
3. Add the product to a dedicated offering (optional: set `REVENUECAT_COACH_SEAT_OFFERING_ID`)

Build with:

```bash
--dart-define=REVENUECAT_COACH_SEAT_PRODUCT_ID=your_store_product_id \
--dart-define=REVENUECAT_COACH_SEAT_ENTITLEMENT_ID=professional_coach_per_seat
```

Subscription UI: `/subscription` · Restore: `/restore-purchases`

After physical device tests, set `success: true` in `mobile/evidence/*.json` and run `npm run validate:mobile-primary-product` from repo root.
