# ArchiveMe rebrand audit

**Date:** 2026-05-25  
**Scope:** Full `voice-memory` monorepo + `apps/voicememory_mobile`  
**Product name:** ArchiveMe  
**Policy:** Replace **user-visible** copy only. Do **not** change package names, bundle IDs, Firebase project IDs, API hosts, or dart-define keys unless a separate infra migration is approved.

---

## Search summary

| Pattern | User-facing hits (before pass) | After automatic pass |
| --- | --- | --- |
| `VoiceMemory` (string literals in UI/email/push) | **0** in `app/`, `components/`, `lib/product`, `lib/trust-copy`, `lib/email` | Already **ArchiveMe** |
| `VoiceMemory` (Flutter theme class names) | ~600 references | **Unchanged** (not user-visible) |
| `VOICE_MEMORY_*` / `voice-memory-iota` | Infra / defines | **Unchanged** |
| `voice_memory` (paths, modules) | Code identifiers | **Unchanged** |
| `Voice Memory` (two words) | Regex in `resurfacing-natural-voice.ts` only | **Unchanged** (banned phrase detector, not branding) |

---

## User-visible replacements (applied)

| File | Old text | Replacement | User visible? |
| --- | --- | --- | --- |
| `apps/voicememory_mobile/lib/app.dart` | `class VoiceMemoryApp` | `class ArchiveMeApp` | no (symbol; `MaterialApp.title` uses `AppConfig.appName`) |
| `apps/voicememory_mobile/lib/main.dart` | `runApp(const VoiceMemoryApp())` | `runApp(const ArchiveMeApp())` | no |
| `apps/voicememory_mobile/tool/ui_screenshot_audit.dart` | `VoiceMemoryApp()` | `ArchiveMeApp()` | no |
| `apps/voicememory_mobile/tool/screenshot_capture.dart` | `VoiceMemoryApp()` | `ArchiveMeApp()` | no |
| `apps/voicememory_mobile/tool/full_visual_audit_runner.dart` | `VoiceMemoryApp()` | `ArchiveMeApp()` | no |
| `public/sw.js` | `VoiceMemory offline shell` | `ArchiveMe offline shell` | no (comment) |
| `lib/server/db.ts` | `[VoiceMemory auth]` | `[ArchiveMe auth]` | no (server log) |
| `lib/server/auth-route-log.ts` | `[VoiceMemory auth]` | `[ArchiveMe auth]` | no |
| `lib/server/sync-route-log.ts` | `[VoiceMemory sync]` | `[ArchiveMe sync]` | no |
| `lib/server/structured-log.ts` | `[VoiceMemory]` | `[ArchiveMe]` | no |
| `lib/server/auth-diagnostics.ts` | `[VoiceMemory auth]` | `[ArchiveMe auth]` | no |
| `lib/server/openai-budget-core.ts` | `[VoiceMemory OpenAI budget]` | `[ArchiveMe OpenAI budget]` | no |

---

## User-visible — already ArchiveMe (verified, no edit required)

| File | Text | User visible? |
| --- | --- | --- |
| `apps/voicememory_mobile/lib/config/app_config.dart` | `appName = 'ArchiveMe'` | yes |
| `apps/voicememory_mobile/ios/Runner/Info.plist` | `CFBundleDisplayName` ArchiveMe; mic permission string | yes |
| `apps/voicememory_mobile/android/app/src/main/AndroidManifest.xml` | `android:label="ArchiveMe"` | yes |
| `android/app/src/main/res/values/strings.xml` | `app_name` / `title_activity_main` ArchiveMe | yes |
| `capacitor.config.ts` | `appName: "ArchiveMe"` | yes |
| `app/layout.tsx` | metadata title / `applicationName` ArchiveMe | yes |
| `lib/email/send-auth-code.ts` | subject + body ArchiveMe | yes |
| `lib/email/archive-monthly-review-email.ts` | subject + footer ArchiveMe | yes |
| `lib/push/fcm-admin.ts` | notification `title: "ArchiveMe"` | yes |
| `apps/voicememory_mobile/lib/screens/onboarding_screen.dart` | eyebrow `ArchiveMe` | yes |
| `apps/voicememory_mobile/lib/widgets/scaffold_shell.dart` | drawer title ArchiveMe | yes |
| `apps/voicememory_mobile/lib/screens/export_screen.dart` | share subject ArchiveMe journal export | yes |
| `apps/voicememory_mobile/lib/screens/account_screen.dart` | ArchiveMe does not sell your journal | yes |
| `apps/voicememory_mobile/lib/billing/value_moment_paywall.dart` | ChatGPT contrast uses ArchiveMe | yes |
| `apps/voicememory_mobile/lib/features/archive_growth/archive_share_discovery.dart` | `brandFooter = 'ArchiveMe'` | yes |
| `lib/distribution/archive-share-cards.ts` | `subline: "ArchiveMe"` | yes |
| Web `app/`, `components/`, `lib/product*`, `lib/trust-copy.ts`, share/export UI | ArchiveMe throughout | yes |
| `apps/voicememory_mobile/pubspec.yaml` | description mentions ArchiveMe | no (pub metadata) |

---

## Intentionally unchanged (not user-visible / infra)

| File | Old text | Why unchanged | User visible? |
| --- | --- | --- | --- |
| `apps/voicememory_mobile/lib/config/app_config.dart` | `VOICE_MEMORY_API_BASE_URL`, `voice-memory-iota.vercel.app` | API / CI dart-define contract | no |
| `apps/voicememory_mobile/lib/config/app_config.dart` | `bundleId = 'com.voicememory.app'` | Store + Firebase binding | no |
| `capacitor.config.ts` | `appId: "com.voicememory.app"`, `scheme: "voicememory"` | Native IDs + deep links | no |
| `apps/voicememory_mobile/ios/Runner/Info.plist` | `CFBundleName` `voicememory_mobile`, URL scheme `voicememory` | Bundle internal name | no |
| `apps/voicememory_mobile/pubspec.yaml` | `name: voicememory_mobile` | Flutter package name | no |
| `package.json` | `"name": "voice-memory"` | npm workspace name | no |
| `lib/theme/voicememory_*.dart` + ~50 widgets | `VoiceMemoryColors`, `VoiceMemoryTypography`, `VoiceMemoryCards` | Internal theme tokens | no |
| `lib/features/search/voice_memory_search.dart` | `VoiceMemorySearchIndex`, `buildVoiceMemorySearchIndex` | Internal search API | no |
| `lib/resurfacing/resurfacing-natural-voice.ts` | regex `voice memory` | Banned generic phrase filter | no |
| `lib/mobile/mobile-independence.ts` | `package:voice_memory/web` | Legacy import guard | no |
| Storage keys / metrics / `voicememory_*` event namespaces | various | Data continuity | no |

---

## Risky replacements — manual review required

| Item | Risk | Recommendation |
| --- | --- | --- |
| **Rename `VoiceMemoryColors` → `ArchiveMeColors`** | Large mechanical diff (~50 files); zero user impact | Defer to `THEME_MIGRATION_AUDIT.md`; optional follow-up PR |
| **Rename `voice_memory_search.dart` / index types** | Breaks imports + tests | Defer unless publishing shared package |
| **`VOICE_MEMORY_API_BASE_URL` → `ARCHIVEME_API_BASE_URL`** | Breaks CI, docs, developer muscle memory | Add alias define only; keep old key one release |
| **`voice-memory-iota.vercel.app` → new host** | Downtime, deep links, App Store review URLs | DNS cutover project; do not string-replace in app |
| **`com.voicememory.app` / RevenueCat / Firebase** | New store listing or dashboard re-link | Product ops; not a copy change |
| **`voicememory.app` vs `hello@voicememory.app` email domain** | Resend sender verification | See `docs/RESEND_DOMAIN_AUTH.md` |
| **Capacitor `scheme: "voicememory"`** | Breaks existing installed deep links | Keep until universal-link migration |
| **SQL migration comments** (`docs/sql/*.sql`) | Historical only | Update when next schema doc refresh |
| **Docs / README / `*_AUDIT.md` files** | Many still say VoiceMemory for history | Reported below; edit in doc-only pass |

---

## Remaining `VoiceMemory` references (post-pass)

All remaining matches are **non–user-visible**:

- **~55 Dart files:** `VoiceMemoryColors`, `VoiceMemoryTypography`, `VoiceMemoryCards` only
- **`voice_memory_search.dart` + test:** `VoiceMemorySearchIndex`, `buildVoiceMemorySearchIndex`
- **`docs/sql/001_auth_sync_schema.sql`, `002_grade_a_schema.sql`:** comment headers (1 line each)
- **Audit/plan markdown:** `REBRAND_FIX_REPORT.md`, `THEME_MIGRATION_AUDIT.md`, `FIRST_TIME_USER_TEST.md`, etc.

**Zero** literal `'VoiceMemory'` user strings remain in `app/`, `components/`, `lib/product`, `lib/email`, or mobile screens checked for this audit.

---

## README / docs (report separately — not auto-edited)

These still contain legacy naming for history, CI, or ops. Update in a dedicated documentation pass:

| Area | Examples |
| --- | --- |
| Mobile release | `docs/MOBILE_BUILD_COMMANDS.md`, `docs/MOBILE_PARITY_PLAN.md`, `apps/voicememory_mobile/docs/*` |
| ASO / deploy | `docs/ASO_POSITIONING.md`, `docs/PRODUCTION_DEPLOY.md`, `REVENUECAT_PRODUCTION_AUDIT.md` |
| Audits | `BACKEND_HEALTH_AUDIT.md`, `REBRAND_FIX_REPORT.md`, `SETTINGS_PRODUCTION_AUDIT.md`, `FIRST_TIME_USER_TEST.md` |
| Plans | `GPT5_ARCHIVE_SYNTHESIS_PLAN.md`, `ARCHIVE_V1_PLAN.md`, etc. |
| Repo root | `README.md` (if present), `package.json` description fields |

---

## Surface checklist

| Surface | Status |
| --- | --- |
| Flutter UI strings / AppBars | **ArchiveMe** |
| Empty states | **ArchiveMe** (shared copy modules) |
| Paywalls / RevenueCat UI copy | **ArchiveMe** |
| Settings / About / Account | **ArchiveMe** |
| Onboarding | **ArchiveMe** |
| Archive / Discover / Search / Timeline | **ArchiveMe** (theme classes only retain old names) |
| Notifications (push + in-app) | **ArchiveMe** |
| Share cards | **ArchiveMe** |
| Email templates | **ArchiveMe** |
| Android `strings.xml` / manifest label | **ArchiveMe** |
| iOS `Info.plist` display name + mic string | **ArchiveMe** |
| Capacitor `appName` | **ArchiveMe** |
| Web metadata | **ArchiveMe** |

---

## Validation

```bash
cd apps/voicememory_mobile && flutter analyze
rg "'VoiceMemory\"|\"VoiceMemory\"|>VoiceMemory<" app components lib --glob '!**/voicememory_*'
```

Expected: no user-facing string matches; analyze may report existing info-level lints unrelated to rebrand.
