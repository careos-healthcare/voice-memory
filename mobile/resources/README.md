# App icons and splash (placeholders)

Capacitor ships default launcher icons in `ios/` and `android/` until you replace them.

## Before store submission

1. Add a **1024×1024** master icon (PNG, no transparency for iOS App Store).
2. Generate platform assets with [@capacitor/assets](https://capacitorjs.com/docs/guides/splash-screens-and-icons) or your design toolchain.
3. Align with web manifest icons (`app/icon.tsx`, `app/apple-icon.tsx`).

## Splash

- iOS: `ios/App/App/Assets.xcassets/Splash.imageset`
- Android: `android/app/src/main/res/drawable*` launch theme

Current status: **placeholder / default Capacitor branding** — not store-ready.
