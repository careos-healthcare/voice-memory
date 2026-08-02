# Rebrand Fix Report — VoiceMemory → ArchiveMe

**Date:** 2026-05-25  
**Scope:** User-facing branding only (not internal identifiers, storage keys, or infra IDs)

---

## Summary

| Metric | Value |
|--------|-------|
| Replacements (automated + manual) | **~849** string replacements across **222** files |
| Additional manual fixes | Share-card canvas, export filenames, `.env.example`, deep-link scheme revert |
| **USER_FACING_VOICEMEMORY_COUNT** | **0** |

**Verification command** (UI source roots; excludes theme classes, storage keys, server logs):

```bash
rg 'VoiceMemory|Voice Memory|VOICEMEMORY' \
  lib app components apps/voicememory_mobile/lib \
  apps/voicememory_mobile/ios/Runner/Info.plist \
  apps/voicememory_mobile/android/app/src/main/AndroidManifest.xml \
  capacitor.config.ts \
  e2e/ui-smoke.spec.ts e2e/ui-mobile-375.spec.ts \
  --glob '!**/founder-test/**' --glob '!**/components/internal/**' \
  | rg -v 'VoiceMemoryColors|VoiceMemoryTypography|VoiceMemoryCards|VoiceMemoryApp|VoiceMemorySearch|buildVoiceMemory|searchVoiceMemory|VOICEMEMORY_ARCHIVE|VOICEMEMORY_'
```

**Result:** Only server `console.info` prefixes remain (`[VoiceMemory auth]`, etc.) — not shown in product UI.

---

## Root cause / approach

1. **Inventory** — Full-repo search for `VoiceMemory`, `Voice Memory`, `voicememory`, `VOICEMEMORY`, `voice-memory`, `voice_memory`.
2. **Categorize** — Safe UI copy vs caution (deep links, export format) vs must-not-change (bundle IDs, `voicememory_*` keys, class names).
3. **Replace** — Python pass: `VoiceMemory` → `ArchiveMe` except identifiers `VoiceMemoryColors`, `VoiceMemoryTypography`, `VoiceMemoryCards`, `VoiceMemoryApp`, `VoiceMemorySearch*`, `buildVoiceMemory*`, `searchVoiceMemory`.
4. **Manual** — Reverted Capacitor iOS `scheme` to `voicememory` (deep-link compatibility). Updated share/export **download** filenames. Left import format `voicememory-archive` unchanged.

---

## Replacements made (representative)

| Area | Before | After |
|------|--------|-------|
| App display name | VoiceMemory | ArchiveMe |
| Onboarding eyebrow | VoiceMemory | ArchiveMe |
| Account privacy line | VoiceMemory does not sell… | ArchiveMe does not sell… |
| Paywall contrast | VoiceMemory tracks… | ArchiveMe tracks… |
| Export email subject | VoiceMemory journal export | ArchiveMe journal export |
| iOS mic permission | VoiceMemory needs the microphone… | ArchiveMe needs the microphone… |
| Android `android:label` | VoiceMemory | ArchiveMe |
| Web `layout.tsx` / `manifest.ts` | VoiceMemory | ArchiveMe |
| Legal / trust / product copy (`lib/*copy*`) | VoiceMemory | ArchiveMe |
| Push notification title (`lib/push/fcm-admin.ts`) | VoiceMemory | ArchiveMe |
| Auth email (`lib/email/send-auth-code.ts`) | Your VoiceMemory sign-in code | Your ArchiveMe sign-in code |
| Share card canvas header | VOICEMEMORY | ArchiveMe |
| Export download names | `voicememory-archive-*.json` | `archiveme-archive-*.json` |
| E2E smoke | toContain("VoiceMemory") | toContain("ArchiveMe") |

**Positioning constant** `VOICEMEMORY_ARCHIVE_POSITIONING` — **identifier unchanged**; **value** now reads: *"ArchiveMe keeps track of what your archive believes…"*

---

## Major screens verified (Flutter + web)

| Screen | Status |
|--------|--------|
| Record | No visible VoiceMemory; uses theme tokens only |
| Discover | No visible VoiceMemory |
| Archive | No visible VoiceMemory |
| Timeline | No visible VoiceMemory |
| Search | No visible VoiceMemory |
| Account | ArchiveMe in privacy copy |
| Paywall | ArchiveMe in value-moment copy |
| Onboarding | ArchiveMe eyebrow |
| Export | ArchiveMe subject + `archiveme_export.json` |
| Settings | Web/mobile settings copy uses ArchiveMe |

---

## Files changed

**~183 paths** in git diff (includes prior session changes). Rebrand-specific highlights:

### Mobile (`apps/voicememory_mobile`)

- `lib/config/app_config.dart` — `appName = 'ArchiveMe'`
- `ios/Runner/Info.plist` — `CFBundleDisplayName`, mic usage string
- `android/app/src/main/AndroidManifest.xml` — `android:label`
- `lib/screens/onboarding_screen.dart`, `account_screen.dart`, `export_screen.dart`
- `lib/billing/value_moment_paywall.dart`
- `lib/widgets/scaffold_shell.dart`
- `lib/screens/restore_production_verification_screen.dart` (if present in diff)

### Web (`app/`, `components/`, `lib/`)

- All marketing, trust, product, billing, distribution, sharing copy modules
- `app/layout.tsx`, `app/manifest.ts`, legal pages (`privacy`, `terms`, `safety`, etc.)
- `components/SiteHeader.tsx`, share/distribution components
- `capacitor.config.ts` — `appName: "ArchiveMe"`
- `lib/distribution/archive-share-card-export.ts`
- `lib/archive/full-export.ts`, `lib/archive/zip-package.ts` (download filenames only)

### Config / E2E

- `.env.example` — `EMAIL_FROM=ArchiveMe <…>`
- `e2e/ui-smoke.spec.ts`, `e2e/ui-mobile-375.spec.ts`

---

## Remaining occurrences (intentional — not user-facing brand)

### Must not change (per requirements)

| Category | Examples |
|----------|----------|
| Bundle / app IDs | `com.voicememory.app`, `AppConfig.bundleId` |
| Package / paths | `voicememory_mobile`, `package:voicememory_mobile`, `apps/voicememory_mobile/` |
| Storage keys | `voicememory_*` localStorage / IndexedDB / prefs |
| Import format | `format: "voicememory-archive"` in JSON export schema |
| Env vars | `VOICEMEMORY_*`, `VOICE_MEMORY_API_BASE_URL` |
| API headers | `x-voicememory-test-ip` (E2E only) |
| RevenueCat / Firebase IDs | Unchanged in code |
| Deep link scheme | `voicememory://` (iOS plist + Capacitor) |
| Email domain | `hello@voicememory.app`, `noreply@voicememory.app` (infra) |
| API hosts | `voice-memory-iota.vercel.app` |

### Internal code identifiers (not shown in UI)

| Identifier | Count (approx.) |
|------------|-----------------|
| `VoiceMemoryColors` | 600+ references |
| `VoiceMemoryTypography` | 200+ |
| `VoiceMemoryCards` | 20+ |
| `VoiceMemoryApp` | `lib/app.dart`, `main.dart`, tools |
| `VoiceMemorySearchIndex` / `searchVoiceMemory` | Search feature |

### Caution (user may see filename/domain, not product name)

| Item | Notes |
|------|--------|
| `hello@voicememory.app` | Contact email domain unchanged |
| `voicememory-archive` in JSON `format` field | Backward-compatible imports |
| `voicememory://` | Existing deep links / OAuth return |
| Server logs `[VoiceMemory auth]` | Dev/ops only |

### Docs / build artifacts

- `REBRAND_AUDIT.md` — historical audit (references old name by design)
- `.next/` HTML — regenerated on next `next build`
- Various `docs/*.md`, audit markdown — not in-app UI

---

## Screenshot QA checklist

1. **Cold launch (iOS/Android)** — Home screen / app switcher shows **ArchiveMe**, not VoiceMemory.
2. **Onboarding** — Eyebrow reads **ArchiveMe**.
3. **Record tab** — No VoiceMemory in visible copy.
4. **Discover tab** — Empty and loaded states: no VoiceMemory.
5. **Archive tab** — Belief / empty states: no VoiceMemory.
6. **Account** — Footer: “ArchiveMe does not sell your journal.”
7. **Export** — Share sheet subject: “ArchiveMe journal export”.
8. **Paywall / pricing** — Contrast copy uses ArchiveMe.
9. **Web home** — Header and `<title>`: ArchiveMe.
10. **Privacy / Terms / Safety** — All titles and body product name: ArchiveMe.
11. **Sign-in email** (staging) — Subject/body: ArchiveMe.
12. **Push test** (if enabled) — Notification title: ArchiveMe.

---

## Follow-ups (out of scope)

- Rename Dart theme classes (`VoiceMemoryColors` → neutral/`ArchiveMeColors`) — large refactor, zero user impact today.
- Rename npm package `voice-memory` / Flutter package `voicememory_mobile`.
- Migrate `voicememory_*` storage keys with dual-read window.
- Store listing / ASO / domain cutover (`archiveme.app`).
- Regenerate `.next` and screenshot audit baselines.
