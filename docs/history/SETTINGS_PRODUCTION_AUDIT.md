# Settings production readiness audit

**App:** `apps/voicememory_mobile`  
**Date:** 2026-05-25  
**Status:** Implemented

---

## Production Settings (release users)

| Item | Implementation |
|------|----------------|
| Account | `/account` |
| Archive Intelligence | `/subscription` |
| Notifications | `/updates` (screen title: Notifications) |
| Privacy | Opens `AppConfig.privacyUrl` |
| Export archive | `/export` |
| Delete account | `/delete-account` |
| Help & support | `mailto:hello@voicememory.app` → fallback `/contact` |
| About ArchiveMe | `/about` (version row = 7-tap unlock target) |

Grouped under: **Account & archive**, **Privacy & data**, **Support**.

---

## Developer Settings (hidden)

Shown only when `DeveloperSettingsGate.canShowDeveloperSettings` is true:

- `AppConfig.isDebugBuild` (`kDebugMode` or `VM_DEBUG_TOOLS` dart-define)
- **OR** seven taps on **Version** on About → persisted `developerSettingsUnlocked`

| Item | Implementation |
|------|----------------|
| API base URL | Inline `_infoTile` |
| Build override | Inline hint (`VOICE_MEMORY_API_BASE_URL`) |
| Backend health | Inline (loaded when section visible) |
| Local journal entries | Inline count |
| RevenueCat verification | `/revenuecat-verify` |
| Restore production verify | `/restore-production-verify` |
| Offline sync verify | `/offline-sync-verify` |
| Push verification | `/native-push-verify` |
| Internal diagnostics | `/developer-diagnostics` |

Verification routes redirect to `/settings` when the gate is closed (`ProductionNavigation`).

---

## Before vs after

### Before (legacy Settings)

- Flat list: Account, **Subscription**, Privacy policy, **Terms**, Export, Delete
- **Developer** block under `kDebugMode` only: API URL, build hint, health, entry count, all verify links
- No Notifications / Help / About sections
- Health + journal counts could appear outside a coherent production layout

### After (current)

- Production sections only (table above)
- Developer block behind `DeveloperSettingsGate` (debug build **or** 7-tap unlock)
- About screen holds version + legal links; unlock does not expose verify tools until user returns to Settings

### Screenshots

Capture on device or emulator:

```bash
cd apps/voicememory_mobile
# Release-like UI (no developer section unless unlocked)
flutter run --release -d <device>
# Account tab → Settings

# Developer section (debug)
flutter run -d <device>
# Or: release → Settings → About ArchiveMe → tap Version 7× → back to Settings

# Optional audit PNG
bash tool/run_ui_screenshot_audit.sh   # includes settings.png under ~/Desktop/upload12/screenshots/
```

Widget tests assert production layout hides developer tools when `suppressDebugBuildForTests` is set (`test/settings_screen_widget_test.dart`).

---

## Files changed

| File | Role |
|------|------|
| `lib/screens/settings_screen.dart` | Production vs developer sections |
| `lib/screens/about_screen.dart` | About + 7-tap version unlock |
| `lib/screens/developer_diagnostics_screen.dart` | Internal diagnostics screen |
| `lib/screens/updates_screen.dart` | Title → Notifications |
| `lib/config/developer_settings_gate.dart` | Gate + unlock logic |
| `lib/config/app_config.dart` | `isDebugBuild`, help/contact URLs |
| `lib/config/production_navigation.dart` | Route guard + `/developer-diagnostics` |
| `lib/main.dart` | Load unlock from prefs at startup |
| `lib/router/app_router.dart` | `/about`, `/developer-diagnostics` |
| `lib/screens/native_push_verification_screen.dart` | Gate instead of `kDebugMode` only |
| `lib/screens/revenuecat_verification_screen.dart` | Gate |
| `lib/screens/offline_sync_verification_screen.dart` | Gate |
| `lib/screens/restore_production_verification_screen.dart` | Gate |
| `lib/widgets/debug_only_unavailable.dart` | Copy update |
| `test/developer_settings_gate_test.dart` | Unlock tests |
| `test/settings_screen_test.dart` | Structure tests |
| `test/settings_screen_widget_test.dart` | Widget visibility tests |
| `test/debug_tools_navigation_test.dart` | Redirect / unlock nav tests |

---

## Debug surfaces still visible in production

| Surface | Visible in release? | Notes |
|---------|---------------------|-------|
| Settings → Developer section | **No** (unless 7-tap unlock persisted) | Primary fix |
| Verify routes (deep link) | **No** | Redirect to `/settings` |
| Drawer verify links | **No** | `ProductionNavigation.isNavRouteVisible` |
| TrustBanner | **No** | `kReleaseMode` hides in `scaffold_shell` |
| Account → Export / Delete / Pricing | **Yes** | Customer actions (not QA tools) |
| `VM_DEBUG_TOOLS=true` release build | **Yes** | Intentional QA compile flag only |
| Console `debugPrint` in debug builds | N/A | Not UI |

---

## Validation

```bash
cd apps/voicememory_mobile
flutter analyze    # 82 info issues, 0 errors (2026-05-25)
flutter test test/settings_screen_test.dart test/settings_screen_widget_test.dart \
  test/developer_settings_gate_test.dart test/debug_tools_navigation_test.dart
```

All settings-related tests pass.
