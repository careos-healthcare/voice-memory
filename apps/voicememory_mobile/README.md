# VoiceMemory Mobile (Flutter)

Native iOS/Android MVP — **record → attest → transcribe → analyze → local journal**.

The Next.js web app at the repo root is **not modified** by this package.

## MVP loop (implemented)

1. Onboarding → Record
2. Microphone permission + AAC recording to temp file
3. `POST /api/capture/attest` (device UUID in secure storage)
4. `POST /api/transcribe` with `x-vm-capture-token`
5. `POST /api/analyze`
6. Save `JournalEntry` to `journal_entries.json` on device
7. Journal list → entry detail → export/share JSON

## Not implemented

- Magic-link / cookie auth
- Server journal sync
- Resurfacing, search, Stripe/IAP, push
- iOS release build (not run in CI here unless stated in report)

## Run

```bash
cd apps/voicememory_mobile
flutter pub get
npm run dev   # from repo root — backend on :3000

flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # Android emulator
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000 # iOS Simulator
```

## Validate

See [VALIDATION.md](./VALIDATION.md).

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Bundle ID

`com.voicememory.app`
