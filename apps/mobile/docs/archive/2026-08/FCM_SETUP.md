# FCM production push setup

## Flutter (dart-define)

```bash
flutter run \
  --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=VM_INTERNAL_DEBUG_TOKEN=your_DEBUG_ACCESS_TOKEN
```

Add `GoogleService-Info.plist` (iOS) and `google-services.json` (Android) per Firebase console.

## Backend (Vercel)

- `FIREBASE_SERVICE_ACCOUNT_JSON` — full service account JSON, **or**
- `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
- `VOICEMEMORY_ENABLE_INTERNAL=true`
- `DEBUG_ACCESS_TOKEN` — matches `VM_INTERNAL_DEBUG_TOKEN` on device

## Verification

1. Settings → Native push verify
2. Request permission (registers token via `POST /api/push/register`)
3. Send Archive / Discover / Record pushes (backend FCM)
4. Tap each notification on device
5. Export JSON → `mobile/evidence/native_push_verification.json`
6. `npm run validate:push-production`
