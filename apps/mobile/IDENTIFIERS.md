# ArchiveMe mobile — identifier policy

This document is the **single source of truth** for naming boundaries after the
VoiceMemory → ArchiveMe rebrand. If something looks like a partial rename, check
here first.

**Policy in one sentence:** rebrand **user-visible copy** and **developer package
names**; keep **store/platform IDs** and **data contracts** on legacy values until
an explicit infra migration is approved.

Historical context: [docs/history/archive/REBRAND_AUDIT.md](../../docs/history/archive/REBRAND_AUDIT.md), [REBRAND_FIX_REPORT.md](../../docs/history/archive/REBRAND_FIX_REPORT.md).

---

## Three identity layers (deliberately different)

| Layer | Canonical value | Who sees it | Rename risk |
| --- | --- | --- | --- |
| **User-facing brand** | **ArchiveMe** | Home screen, onboarding, store listing title, in-app copy | Low — copy-only |
| **Developer / build identity** | **`archiveme_mobile`** (Dart package), `apps/mobile/` (repo path) | `import` paths, CI, tests | Low — tooling only |
| **Store / platform identity** | **`com.voicememory.mobile`** | Play Console, App Store Connect, adb, RevenueCat, widgets, push | **High — treat as immutable** |

These layers **are meant to diverge**. The Dart package name does not appear on
device or in either store. The Android `applicationId` and iOS bundle ID do not
appear in user-facing UI.

---

## Canonical platform identifiers (do not change casually)

| Identifier | Value | Primary source |
| --- | --- | --- |
| Public app name | `ArchiveMe` | `lib/config/app_config.dart` → `AppConfig.appName`; iOS `CFBundleDisplayName`; Android `android:label` |
| iOS bundle ID | `com.voicememory.mobile` | `ios/Runner.xcodeproj/project.pbxproj`, `AppConfig.bundleId` |
| Android application ID | `com.voicememory.mobile` | `android/app/build.gradle.kts` (`applicationId`, `namespace`) |
| Android Kotlin package | `com.voicememory.mobile` | `android/app/src/main/kotlin/com/voicememory/mobile/` |
| iOS App Group | `group.com.voicememory.mobile` | `ios/Runner/Runner.entitlements`, widget entitlements |
| Widget extension ID | `com.voicememory.mobile.TodayCheckWidget` | Xcode widget target |
| Watch app ID | `com.voicememory.mobile.watchkitapp` | `ios/WatchApp/` (when enabled) |
| Test target ID | `com.voicememory.mobile.RunnerTests` | `project.pbxproj` |

**Deprecated (must not reappear in active config):** `com.voicememory.app` — an
older bundle id; guarded by `test/release_identity_consistency_test.dart`.

---

## Legacy identifiers kept on purpose (not user-visible brand)

These still use `voicememory` / `VOICE_MEMORY` prefixes for **continuity**. Do not
rename without a migration plan and dual-read window.

| Category | Examples | Why unchanged |
| --- | --- | --- |
| Build / runtime defines | `VOICE_MEMORY_API_BASE_URL`, `VOICE_MEMORY_SCREENSHOT_MODE` | CI scripts, launch configs, hundreds of test call sites |
| Deep link URL schemes | `voicememory://` (legacy), `archiveme://` (current) | Existing links, OAuth returns, widget prep |
| Local storage keys | `voicememory_*` prefs / SQLite namespaces | On-device data continuity across upgrades |
| Export JSON schema | `format: "voicememory-archive"` | Backward-compatible imports |
| API host (production) | `voice-memory-iota.vercel.app` | Deployed backend; separate infra migration |
| RevenueCat / IAP product IDs | e.g. `com.voicememory.app.pro.monthly` | Tied to store listings and dashboard config |
| Internal theme symbols | `VoiceMemoryColors`, `voicememory_typography.dart` | Not rendered as product name; large refactor, zero user impact |
| Firebase / push project binding | Firebase options files | Tied to registered app IDs |

---

## What was renamed (safe)

| Before | After | Notes |
| --- | --- | --- |
| User-visible strings `VoiceMemory` | `ArchiveMe` | Onboarding, paywall, export subject, legal copy, etc. |
| Dart package `voicememory_mobile` | `archiveme_mobile` | `pubspec.yaml` `name:` — affects imports only |
| Repo path `apps/voicememory_mobile/` | `apps/mobile/` | Docs may still reference old path; see `voicememory_mobile/README.md` parity shim |
| Root widget class `VoiceMemoryApp` | `ArchiveMeApp` | Symbol rename; `MaterialApp.title` uses `AppConfig.appName` |

---

## Why store IDs stay `com.voicememory.mobile`

Changing Android `applicationId` or iOS `PRODUCT_BUNDLE_IDENTIFIER` after store
registration is a **new-app migration**, not a rename:

1. **Play Store / App Store** — new listing; existing installs do not receive updates in place.
2. **RevenueCat & IAP** — entitlements and product IDs are registered against the current app id.
3. **Push notifications** — FCM/APNs registration is bound to bundle/application id.
4. **Platform extensions** — widgets, App Groups, Watch targets, and Kotlin/Java package paths all hang off `com.voicememory.mobile`.
5. **Deep links & OAuth** — `voicememory://` handlers remain for installs that bookmarked legacy URLs.

The rebrand intentionally separated **marketing name** (ArchiveMe) from **platform
identity** (com.voicememory.mobile). That matches the original rebrand rule: *do
not change bundle IDs unless a separate infra migration is approved*.

---

## If you need to change a frozen identifier

Treat this as a **migration project**, not a find-and-replace:

1. Write an explicit migration plan (dual-read period, data backfill, store cutover).
2. Update Play Console / App Store Connect / RevenueCat / Firebase in lockstep.
3. Add redirect handling for deep links and export format versioning.
4. Extend `test/release_identity_consistency_test.dart` and release checklists.
5. Get explicit approval before merging — do not drive-by rename in a feature PR.

---

## Enforcement & related docs

**Automated checks**

- `test/release_identity_consistency_test.dart` — canonical bundle id, App Group, no `com.voicememory.app` in active config
- `test/consumer_visible_branding_test.dart` — no legacy brand strings in user-visible UI
- `test/mobile_production_readiness_test.dart` — `AppConfig.bundleId` assertion

**Release checklists** (reference this doc, duplicate ids for convenience)

- [docs/IOS_RELEASE_CHECKLIST.md](./docs/IOS_RELEASE_CHECKLIST.md)
- [docs/ANDROID_RELEASE_CHECKLIST.md](./docs/ANDROID_RELEASE_CHECKLIST.md)
- [APP_STORE_SUBMISSION_PACK.md](./APP_STORE_SUBMISSION_PACK.md)

**Quick adb reference**

```bash
adb shell monkey -p com.voicememory.mobile 1
```
