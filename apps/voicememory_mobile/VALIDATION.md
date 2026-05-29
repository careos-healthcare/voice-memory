# Validation commands

Run from this directory:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

### API URL for device testing

```bash
# Android emulator → host machine Next.js
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# iOS Simulator
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Start the web backend first: from repo root, `npm run dev` (port 3000).
