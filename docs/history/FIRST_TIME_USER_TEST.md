> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# First-Time User Test — ArchiveMe (Flutter)

**Date:** 2026-05-25  
**App:** `apps/voicememory_mobile`  
**Goal:** Simulate a brand-new App Store install — empty archive, honest copy, no seeded data.  
**Constraint:** Procedure and commands only. **Do not run destructive commands unless you choose to.**

---

## App identity (for uninstall / clear commands)

| Platform | Package / bundle ID | Home-screen name (current) |
|----------|---------------------|----------------------------|
| **Android** | `com.voicememory.app` | ArchiveMe (`AndroidManifest.xml`) |
| **iOS (Runner)** | `com.voicememory.mobile` | ArchiveMe (`CFBundleDisplayName`) |

> iOS bundle ID in Xcode may differ from Android `applicationId`. Use the ID from the table for each platform’s uninstall/clear commands.

---

## Local data map (what “fresh user” means in code)

All primary local state lives under the app **Documents** directory (`getApplicationDocumentsDirectory()`):

| File / store | Path (relative to Documents) | Clears |
|--------------|-------------------------------|--------|
| Journal (recordings index + transcripts) | `journal_entries.json` | Cached journal / archive entries |
| App preferences (JSON, not Android `SharedPreferences` plugin) | `mobile_prefs.json` | Onboarding (`onboardingCompleted`), discover baseline, theory notifications, value-moment paywall, archive snapshot (`archiveStateSnapshot`), return-reason, daily discovery, surprise/evolution/challenge stores, identity profile cache, memory resurfacing, offline sync journey, blind-spot reactions |
| Entitlements cache | `entitlements.json` | Local Pro/free cache (not store receipt) |
| Secure storage (Keychain / EncryptedSharedPreferences) | Keys prefixed `vm_flutter_` | Session cookie (`auth_cookie`), other secure prefs |
| Audio captures | Under Documents (recording pipeline) | Uninstall or delete Documents contents |

**Onboarding flag:** `mobile_prefs.json` → `"onboardingCompleted": true|false`  
**Synthetic updates (if present):** `mobile_prefs.json` → `"theoryNotifications": [...]`

There is **no** separate Flutter `shared_preferences` XML file for core archive data — clearing “shared preferences” for this app means **deleting `mobile_prefs.json`** (and related files) or **uninstalling the app**.

---

## 1. Reset commands by platform

Replace `<BUNDLE_ID>` / package name with the values in the table above.

### 1.1 iOS Simulator

**Uninstall app (removes app container, Keychain entries for bundle, Documents):**

```bash
# List booted simulator
xcrun simctl list devices booted

# Uninstall (use installed bundle ID — typically com.voicememory.mobile)
xcrun simctl uninstall booted com.voicememory.mobile
```

**Optional — erase entire simulator (nuclear; removes all apps on that device):**

```bash
xcrun simctl erase booted
```

**Optional — manual file delete without full erase (app must stay installed):**

```bash
# App data container path
CONTAINER=$(xcrun simctl get_app_container booted com.voicememory.mobile data)
echo "$CONTAINER"

# Remove journal + prefs + entitlements (onboarding + archive state)
rm -f "$CONTAINER/Documents/journal_entries.json"
rm -f "$CONTAINER/Documents/mobile_prefs.json"
rm -f "$CONTAINER/Documents/entitlements.json"

# Remove other files in Documents (audio, exports)
rm -rf "$CONTAINER/Documents/"*
# Recreate empty docs if needed — app will recreate [] / {} on next launch
```

**Clear secure storage:** Uninstall is the reliable approach on Simulator. Keychain items use prefix `vm_flutter_` (e.g. `vm_flutter_auth_cookie`).

**Reinstall after uninstall:**

```bash
cd /Users/chiragpatel/Desktop/voice-memory/apps/voicememory_mobile
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://127.0.0.1:3000
```

---

### 1.2 Android Emulator

**Uninstall:**

```bash
adb uninstall com.voicememory.app
```

**Clear app data (keeps APK installed; wipes internal storage + cache):**

```bash
adb shell pm clear com.voicememory.app
```

Equivalent to: local storage + preferences + cache for the package.

**Optional — manual delete (debuggable builds only):**

```bash
adb shell run-as com.voicememory.app rm -f files/journal_entries.json
adb shell run-as com.voicememory.app rm -f files/mobile_prefs.json
adb shell run-as com.voicememory.app rm -f files/entitlements.json
```

(Path may vary; `run-as` fails on release builds without debuggable flag.)

**Reinstall:**

```bash
cd /Users/chiragpatel/Desktop/voice-memory/apps/voicememory_mobile
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://10.0.2.2:3000
```

---

### 1.3 Physical iPhone

1. **Delete the app** from the Home Screen (long press → Remove App → Delete App).  
   This removes Documents, caches, and app Keychain items for that bundle.

2. **Settings → General → iPhone Storage → ArchiveMe → Delete App** (if still listed).

3. **Do not use** “Offload App” alone if you need a true fresh install — offload may preserve data.

4. Reinstall via TestFlight, Xcode, or `flutter install` after a release/debug build.

**No `adb`-style CLI** for consumer devices without MDM/Xcode device tools. For QA devices enrolled in Apple Configurator / Xcode Devices window, use **Devices and Simulators → Installed Apps → Delete**.

---

### 1.4 Physical Android device

1. **Settings → Apps → ArchiveMe → Storage → Clear storage** (or **Clear data**).  
   Clears journal, `mobile_prefs.json`, cache, secure storage for the app.

2. Or **Uninstall**, then reinstall from Play internal track / APK.

```bash
# USB debugging enabled
adb uninstall com.voicememory.app
# Reinstall APK/AAB from CI or:
cd /Users/chiragpatel/Desktop/voice-memory/apps/voicememory_mobile
flutter install --dart-define=VOICE_MEMORY_API_BASE_URL=https://voice-memory-iota.vercel.app
```

---

### 1.5 Checklist — “brand-new user” verification

After reset, before launch:

- [ ] App not installed **OR** `pm clear` / uninstall completed  
- [ ] No `journal_entries.json` with `audit-entry-*` or `screenshot-sample-*` IDs (dev machine only)  
- [ ] `mobile_prefs.json` absent or `{}` / no `onboardingCompleted: true`  
- [ ] Not running with `--dart-define=VISUAL_AUDIT=true`  
- [ ] Release-like build for store simulation (see §2)

---

## 2. Clean rebuild checklist

Run from repo:

```bash
cd /Users/chiragpatel/Desktop/voice-memory/apps/voicememory_mobile

flutter clean

flutter pub get

flutter analyze

flutter test
```

**Generated files:** This project does **not** use `build_runner` in `pubspec.yaml`. Plugin registrants are produced by Flutter on build (`GeneratedPluginRegistrant` in `ios/` / `android/`). No separate codegen step required beyond `flutter pub get`.

**Rebuild app (pick target):**

```bash
# API host (production-like)
export API=https://voice-memory-iota.vercel.app

# iOS Simulator
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=$API

# Android Emulator (host loopback)
flutter run --dart-define=VOICE_MEMORY_API_BASE_URL=http://10.0.2.2:3000

# iOS release binary (then Archive in Xcode)
flutter build ios --release --dart-define=VOICE_MEMORY_API_BASE_URL=$API

# Android release bundle
flutter build appbundle --release --dart-define=VOICE_MEMORY_API_BASE_URL=$API
```

**Store-like subscription test (optional):**

```bash
flutter run \
  --dart-define=VOICE_MEMORY_API_BASE_URL=$API \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_YOUR_KEY \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_YOUR_KEY
```

---

## 3. Launch QA flow (10 steps)

Use one continuous session on a **reset device**. Record screenshots per step.

| Step | Action |
|------|--------|
| 1 | Fresh install (§1) |
| 2 | Cold launch app |
| 3 | Complete onboarding |
| 4 | First recording (Record tab) |
| 5 | Discover tab |
| 6 | Search tab |
| 7 | Updates screen (see access note below) |
| 8 | Archive tab |
| 9 | Subscription (`Account → Pricing`) |
| 10 | Account tab |

**Updates screen access:** Route `/updates` is registered in `app_router.dart` but **not linked** from bottom nav, Settings, or Archive drawer in production. `/archive-detail` redirects to Archive. For QA:

- **Debug session:** Use Flutter DevTools → **GoRouter** → navigate to `/updates`, or breakpoint and `context.push('/updates')`.
- **Document expected UI** below assuming 0–1 recordings (no synthetic notification until 2+ eligible entries).

---

## 4. Per-step expectations

For each step: **Should see** | **Should NOT see** | **ArchiveMe?** | **Fake data?** | **Misleading analytics?**

---

### Step 1 — Fresh install

| | |
|--|--|
| **Should see** | Install completes; icon shows **ArchiveMe** (current store label) |
| **Should NOT see** | Pre-populated journal; TestFlight “sample” data |
| **ArchiveMe?** | **Yes** — display name / launcher label not yet ArchiveMe |
| **Fake data?** | No |
| **Misleading analytics?** | No |

---

### Step 2 — First app launch

| | |
|--|--|
| **Should see** | Redirect to `/onboarding` (onboarding gate incomplete) |
| **Should NOT see** | Archive tabs; belief cards; timeline entries; “Archive growing” notification |
| **ArchiveMe?** | Not on first frame until onboarding UI loads |
| **Fake data?** | No |
| **Misleading analytics?** | No |

---

### Step 3 — Onboarding

| | |
|--|--|
| **Should see** | Five educational slides (archive / evidence / beliefs); `ArchiveQuickExplainCard` with 0 reflections; **Next** / **Skip**; final slide “Record your first reflection.” |
| **Should NOT see** | Sample transcripts; theme tables; confidence %; charts |
| **ArchiveMe?** | **Yes** — eyebrow text `'ArchiveMe'` on onboarding (`onboarding_screen.dart`) |
| **Fake data?** | No |
| **Misleading analytics?** | No — product education only |

**After Skip/Finish:** Lands on `/archive-belief` (initial shell location).

---

### Step 4 — First recording (Record tab)

| | |
|--|--|
| **Should see** | Mic permission prompt (first time); record UI (ready / recording / processing); low-effort prompts optional; after save: success copy, optional “still learning” belief card — **from your recording only** |
| **Should NOT see** | Pre-filled journal list; audit `audit-entry-*` transcripts; post-save fake “work stress pattern” without your words |
| **ArchiveMe?** | No user-facing string on main record chrome (theme class names only) |
| **Fake data?** | No |
| **Misleading analytics?** | No on first save; thin-keyword “noticed” lines only after real transcript |

**QA:** Grant microphone; record ≥30s with clear speech (≥24 chars transcript) for downstream evidence tests.

---

### Step 5 — Discover tab (`/discover-yourself`)

**Before any recording:**

| | |
|--|--|
| **Should see** | Title “Discover Yourself”; **“Your archive is empty”**; body “Record your first thought…”; **“Create First Recording”**; progress card **“Your archive starts with one recording”** (no 0/0 metrics, no View Growth) |
| **Should NOT see** | “Beginning to notice patterns”; theme sections; belief cards; weekly story; 0% confidence; streak counters; charts |
| **ArchiveMe?** | No on empty panel (internal `VoiceMemoryTypography` only) |
| **Fake data?** | No |
| **Misleading analytics?** | No |

**After 1+ recordings (still below full evidence):**

| | |
|--|--|
| **Should see** | Lead: “Belief changes, themes, and chapters from your recordings.”; sections gated by engine; early banner may ask for more spoken detail |
| **Should NOT see** | Fabricated beliefs; seeded `screenshot-sample-*` entries |
| **Fake data?** | No |
| **Misleading analytics?** | Low — keyword themes from **your** text only |

---

### Step 6 — Search tab (`/search`)

**Zero recordings, empty search field:**

| | |
|--|--|
| **Should see** | **“No recordings yet”**; body “Record your first thought…”; **“Create First Recording”** |
| **Should NOT see** | “Nothing found yet”; suggestion tiles with fake entries; belief preview |
| **ArchiveMe?** | No |
| **Fake data?** | No |
| **Misleading analytics?** | No |

**With recordings, empty query:**

| | |
|--|--|
| **Should see** | “Search your archive” + idle helper text |
| **Should NOT see** | “Nothing found yet” |

---

### Step 7 — Updates screen (`/updates`)

**Access:** Manual navigation to `/updates` (see §3).

**Zero–one recordings:**

| | |
|--|--|
| **Should see** | Title “Updates”; note “In-app theory updates only…”; **“No updates yet.”** |
| **Should NOT see** | “Archive growing” card; unread badge from synthetic `local-1` |
| **ArchiveMe?** | **Yes** — if synthetic notification appears (≥2 eligible entries): body mentions **ArchiveMe** |
| **Fake data?** | **Yes (after 2+ reflections)** — auto-inserted notification (not push); persists in `theoryNotifications` |
| **Misleading analytics?** | **Yes (after 2+)** — implies product already analyzed archive |

**QA sub-test:** With exactly 0–1 recordings, confirm **no** fake update row.

---

### Step 8 — Archive tab (`/archive-belief`)

**Zero recordings:**

| | |
|--|--|
| **Should see** | **“No recordings yet”** panel (via `FirstReflectionEmptyArchiveSection` / `EmptyArchivePanel`); single CTA to record |
| **Should NOT see** | Living archive evolution hero; belief banner; top themes table; milestones; memory resurfacing; evidence locker |
| **ArchiveMe?** | No |
| **Fake data?** | No |
| **Misleading analytics?** | No |

**1–4 recordings (immediate mode):**

| | |
|--|--|
| **Should see** | “Your archive is still learning”; comparisons from **your** transcripts |
| **Should NOT see** | Full belief dossier below evidence guard |
| **Misleading analytics?** | Possible thin “noticed” copy — must cite user words |

**5+ reflections, below minimum evidence:**

| | |
|--|--|
| **Should see** | **“We need more evidence”** panel; theme placeholder copy; watch nudge to record more |
| **Should NOT see** | “Nothing notable has shifted…”; confidence %; fake beliefs |
| **Misleading analytics?** | Reduced after empty-state polish; watch line still instructional |

---

### Step 9 — Subscription flow

**Path:** Account tab → **Pricing** → `/subscription`

| | |
|--|--|
| **Should see** | Offerings load (if RevenueCat configured) or **“Subscriptions are temporarily unavailable.”**; monthly/yearly packages when configured; Restore path via `/restore-purchases` |
| **Should NOT see** | Hardcoded prices unrelated to store; browser Stripe checkout in production shell |
| **ArchiveMe?** | Check paywall copy in `value_moment_paywall.dart` if triggered from Discover |
| **Fake data?** | No |
| **Misleading analytics?** | No |

**Release build without `REVENUECAT_*` dart-defines:** expect unavailable message — not a fake “Pro active” unless cache bug (see `REVENUECAT_PRODUCTION_AUDIT.md`).

---

### Step 10 — Account screen

| | |
|--|--|
| **Should see** | Session: “Not signed in” (guest-first); email/code sign-in; Sync; Pricing; Export; Delete account; Settings; privacy link |
| **Should NOT see** | Stranger’s email pre-filled; fake sync “last synced now” without action |
| **ArchiveMe?** | **Yes** — footer “ArchiveMe does not sell your journal.” |
| **Fake data?** | No |
| **Misleading analytics?** | No |

**Settings:** Local journal entry count `0` after fresh install; no Updates link.

---

## 5. Supplementary routes (optional QA)

| Route | Fresh-user expectation |
|-------|------------------------|
| `/timeline` | Same first-recording empty panel as Search/Archive |
| `/journal` | “No recordings yet” panel (via drawer → Reflection Log) |
| `/archive-identity` | Record-more CTA; no trait cards |
| `/blind-spots` | “Not enough reflections yet” |
| `/weekly-story` | No card on Discover when engine returns null |

---

## 6. Screenshot checklist (QA deliverables)

| # | Screen | State |
|---|--------|-------|
| 1 | Onboarding slide 1 | First launch |
| 2 | Onboarding eyebrow | Shows ArchiveMe branding |
| 3 | Archive | 0 recordings |
| 4 | Discover | 0 recordings |
| 5 | Search | 0 recordings, empty query |
| 6 | Timeline | 0 recordings |
| 7 | Record | Ready state |
| 8 | Record | Post–first save |
| 9 | Discover | 1 recording |
| 10 | Updates | 0–1 recordings (no fake row) |
| 11 | Account | Not signed in |
| 12 | Subscription | RC configured vs unavailable |
| 13 | Updates | 2+ recordings (document synthetic notification if still present) |

---

## LAUNCH BLOCKERS

Issues that risk **App Store rejection**, **brand confusion**, or **first-time user distrust**.

### P0 — User trust / misleading empty state

| Issue | Evidence | Impact |
|-------|----------|--------|
| **Synthetic Updates notification** | `updates_screen.dart` inserts `local-1` “Archive growing” after ≥2 reflections; mentions **ArchiveMe** | User believes app shipped with prior notifications / analysis |
| **Updates screen unreachable in production shell** | `/updates` not in nav; `/archive-detail` redirects | QA/store reviewers cannot validate Updates; orphaned feature |

### P0 — Brand / App Store metadata

| Issue | Evidence | Impact |
|-------|----------|--------|
| **Product still branded ArchiveMe in store-facing places** | `CFBundleDisplayName`, `AndroidManifest` label, onboarding eyebrow, account footer, mic permission string, export subject | ArchiveMe rebrand incomplete; reviewer mismatch with marketing |
| **iOS mic permission string** | `NSMicrophoneUsageDescription` → “ArchiveMe needs the microphone…” | App Store privacy review / user confusion |

### P1 — Subscription / billing (ship blockers)

| Issue | Evidence | Impact |
|-------|----------|--------|
| **RevenueCat not configured in release builds** | Missing `REVENUECAT_*` dart-defines → “temporarily unavailable” | IAP broken in production |
| **Android release signing still debug** | Per `REVENUECAT_PRODUCTION_AUDIT.md` / release checklists | Play Console rejection |
| **Entitlement cache vs store drift** | Stale Pro from cache when store says free | Users see wrong paywall state |

### P1 — Discoverability / polish

| Issue | Evidence | Impact |
|-------|----------|--------|
| **Bundle ID mismatch iOS vs Android** | `com.voicememory.mobile` vs `com.voicememory.app` | Deep links, universal links, support docs confusion |
| **No deep link intent-filter on Android** | `AndroidManifest.xml` launcher only | Marketing links cannot open in-app routes |

### P2 — Post-fix residual risks

| Issue | Evidence | Impact |
|-------|----------|--------|
| **Early archive keyword insights (1–4 recordings)** | Immediate archive mode | Can feel like “analytics” if headlines overclaim |
| **Evolution headline “work stress”** | `archive_evolution_engine.dart` when themes match | Must never show without real comparisons |
| **Dev fixture IDs on device** | `audit-entry-*`, `screenshot-sample-*` if visual audit run on device | Looks like fake data — delete app data |

### Not launch blockers (verified for fresh install)

- No bundled `journal_entries.json` seed in production `lib/`
- `VISUAL_AUDIT` tooling gated to test/define
- Empty-state polish on Search / Discover / Archive zero paths (see `EMPTY_STATE_FIXES.md`)
- Timeline / Journal honest empty CTAs

---

## Related documents

- `EMPTY_STATE_AUDIT.md` — sample/demo audit  
- `EMPTY_STATE_FIXES.md` — copy changes applied  
- `REBRAND_AUDIT.md` — ArchiveMe → ArchiveMe strings  
- `apps/voicememory_mobile/REVENUECAT_PRODUCTION_AUDIT.md` — billing ship criteria  
- `apps/voicememory_mobile/docs/MOBILE_BUILD_COMMANDS.md` — build commands  

---

*End of first-time user test procedure.*

