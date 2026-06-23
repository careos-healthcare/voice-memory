# ArchiveMe Mobile (Flutter)

Native iOS/Android app — **record → transcribe → analyze → local journal → Archive Home**.

The Next.js web app at the repo root is a separate package.

## Core loop (implemented)

1. Onboarding → Record
2. Microphone permission + AAC recording
3. API attest / transcribe / analyze (when connected)
4. Save `JournalEntry` locally
5. Archive Home, evidence tools, export/share

## Billing (not launch-ready)

RevenueCat + native IAP code exists, but **purchases are unavailable** until store/RevenueCat setup completes (see `REVENUECAT_LAUNCH_BLOCKERS.md`). No Stripe checkout in the mobile app.

## Run

```bash
cd apps/voicememory_mobile
flutter pub get
npm run dev   # from repo root — backend on :3000

flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://127.0.0.1:3000
```

## Validate (launch-focused)

See [LAUNCH_VALIDATION.md](./LAUNCH_VALIDATION.md) — not the full historical test suite.

```bash
flutter test test/launch_hardening_test.dart
flutter build ios --release --no-codesign
```

From repo root:

```bash
./scripts/validate-mobile-clean-working-tree.sh
```

## Bundle ID

`com.voicememory.app`
