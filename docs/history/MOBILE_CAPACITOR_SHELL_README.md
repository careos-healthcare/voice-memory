> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# ArchiveMe — native mobile shell (Capacitor)

This folder supports **iOS and Android store shells** that load the existing **Next.js web app**. There is **no Flutter** code and **no native UI rewrite** in this repo.

## Strategy

- **Capacitor** wraps a WebView pointed at your deployed origin (`capacitor.config.ts` → `server.url`).
- The web app remains the source of truth for UI, APIs, auth cookies, Stripe Checkout, journal sync, and resurfacing.
- This is **not native parity** — it is the lowest-risk path to App Store / Play Store distribution.

## What is not included

- **Push notifications** are not live (scheduler is placeholder-only).
- **Stripe IAP** is not wired; billing uses web Stripe Checkout in the WebView.
- **Background recording** while locked is not supported.

## Commands

```bash
# Sync native projects after config/plugin changes
npm run mobile:sync

# First-time or refresh (same as sync, with hints)
npm run mobile:init

# Open Xcode / Android Studio
npm run mobile:ios
npm run mobile:android

# Validate scaffold (CI-safe, no device required)
npm run validate:mobile-native
```

## Local development

1. Start the web app: `npm run dev`
2. Point the shell at localhost:

```bash
CAPACITOR_SERVER_URL=http://localhost:3000 npm run mobile:sync
npm run mobile:ios   # or mobile:android
```

Use a machine-reachable host (not `localhost` on a physical device — use your LAN IP).

## Production

Set `CAPACITOR_SERVER_URL` or `NEXT_PUBLIC_APP_URL` to your production HTTPS origin before `mobile:sync`.

## Icons and splash

See `mobile/resources/README.md` — placeholders use default Capacitor assets until brand assets are added.

## Deep links

Custom scheme: `voicememory://` (auth and billing paths map to web routes). Universal Links / App Links require server configuration — see `docs/MOBILE_NATIVE_SETUP.md`.

## Secure storage

Session auth stays in **httpOnly cookies** on the web origin. `@capacitor/preferences` is for non-sensitive native flags only — see `lib/mobile/secure-storage.ts`.
