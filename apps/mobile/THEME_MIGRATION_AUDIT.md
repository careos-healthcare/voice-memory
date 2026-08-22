# Theme Migration Audit — ArchiveMe Mobile

**Date:** 2026-05-25  
**Scope:** `apps/voicememory_mobile` (Flutter) + repo-wide search for pure black/white literals  
**Design tokens:** Background `#FAFAFC`, Primary `#4F46E5`, Secondary `#A78BFA`, Cards `#FFFFFF`, Text `#111827`, Discovery `#F59E0B`

---

## Executive summary

The indigo/lavender rebrand was wired in `AppTheme.light()` and `MainShell`, but **post-save widgets on Record** still used **legacy dark surfaces** (notably `ArchiveMovementCard` with `#1a1028`). That made Record look like a dark-theme app after the first successful capture.

**Root cause:** Child widgets with hardcoded dark `Color(0xFF…)` backgrounds, not missing `MaterialApp` theme.

**Remediation:** Migrated dark archive widgets to `VoiceMemoryColors`, forced `themeMode: ThemeMode.light`, replaced remaining `Colors.white` UI with `VoiceMemoryColors.onPrimary` on gradient heroes only.

---

## 1. Project-wide search — pure black / white

| Pattern | Dart (`lib/`) | Web (`app/`, `components/`) |
|--------|---------------|-------------------------------|
| `Colors.black` | **0** | N/A (separate stack) |
| `Color(0xFF000000)` | **0** | — |
| `Colors.white` | **0** in widgets/screens after migration | — |
| `Color(0xFFFFFFFF)` | **2** — token definitions only (`surface`, `onPrimary` in `voicememory_colors.dart`) | — |

No pure-black UI surfaces in mobile `lib/`. White is limited to design tokens and **on-primary text on indigo gradient heroes** (belief banner, progress identity card).

---

## 2. `record_screen.dart` — `backgroundColor:` / `color:`

Record has **no own `Scaffold`**; it lives inside `MainShell` (`VoiceMemoryColors.background`).

| Usage | Source | Compliant? |
|-------|--------|------------|
| Body / muted copy | `VoiceMemoryColors.textSecondary` | Yes |
| Recording status card | `VoiceMemoryColors.surface`, `primaryIndigo` | Yes |
| Success / discovery accents | `captureSuccess`, `Theme.of(context).colorScheme.error` | Yes |
| Post-save movement | `ArchiveMovementCard` → now light surface | **Fixed** |

---

## 3. Findings (A–D)

### A. Hardcoded colors still present (before fix → after)

| File | Before | After |
|------|--------|-------|
| `archive_movement_card.dart` | `#1a1028`, lavender on dark | `VoiceMemoryColors.surface` + indigo border |
| `archive_state_delta_card_mobile.dart` | `#1A1030`, `#0F0F12` | `surface` / `surfaceSecondary` |
| `archive_latest_milestone_mobile.dart` | `#0C1929` | `surface` + `chapterBlue` accent |
| `archive_watch_card_mobile.dart` | `#1C1910` | `discoveryGoldBackground` |
| `archive_belief_header_mobile.dart` | dark divider `0x22FFFFFF` | `VoiceMemoryColors.border` |
| `archive_progress_bar_mobile.dart` | `#27272A` track | `surfaceSecondary` + `primaryIndigo` |
| `archive_reputation_card_mobile.dart` | `Colors.white` unfilled meter | `surfaceSecondary` |
| `top_themes_section.dart` | raw hex trends | `themeLavender` / `contradictionRose` |
| Gradient heroes | `Colors.white` text | `VoiceMemoryColors.onPrimary` |

### B. Widgets bypassing `Theme.of(context)`

These intentionally use **`VoiceMemoryColors`** (static tokens aligned with `AppTheme.light()`). Acceptable per migration goal.

| Widget | Notes |
|--------|-------|
| `MainShell` | `VoiceMemoryColors.background` / `surface` on shell + nav |
| `ArchiveMovementCard` | Migrated to tokens |
| `IndigoCaptureWaveform` | Indigo bars only — no black |
| `ImmediateDiscoveryCard`, `living_archive_*` | Already on light tokens |

### C. Screens not using `VoiceMemoryColors` directly

Many screens use **`AppTheme.*` aliases**, which map 1:1 to `VoiceMemoryColors` (`app_theme.dart`). Functionally compliant; prefer `VoiceMemoryColors` or `Theme.of(context).colorScheme` for new code.

### D. Screens not using `AppTheme.light()`

All tab screens inherit theme from `MaterialApp`. **Verified:** `lib/app.dart` sets `theme: AppTheme.light()` and **`themeMode: ThemeMode.light`**.

---

## 4. `lib/app.dart` verification

```dart
theme: AppTheme.light(),
themeMode: ThemeMode.light,
```

`AppTheme.light()` builds `ColorScheme` from `VoiceMemoryColors` (background, primary indigo, secondary lavender, surface, text).

---

## 5. Primary tab screens — compliance matrix

| Screen | Theme compliant? | Hardcoded colors? | Needs migration? |
|--------|------------------|-------------------|------------------|
| **RecordScreen** | Yes (shell + tokens; `AppTheme` removed for muted) | None on screen; child cards fixed | No |
| **ArchiveScreen** (`archive_belief_screen.dart`) | Yes via `AppTheme` / theme widgets | None in screen file; widgets migrated | No |
| **DiscoverScreen** | Yes (`AppTheme` + some `VoiceMemoryColors`) | None critical | Optional: replace `AppTheme` with `Theme.of` for consistency |
| **TimelineScreen** | Yes (`AppTheme` = tokens) | None | Optional consistency pass |
| **SearchScreen** | Yes (`AppTheme.background/surface`) | None | Optional consistency pass |
| **AccountScreen** | Yes (`AppTheme` + `Theme.of` for errors) | None | No |

**Record screen target palette (idle + post-save):**

| Role | Token | Hex |
|------|-------|-----|
| Background | `VoiceMemoryColors.background` | `#FAFAFC` |
| Primary actions / waveform | `primaryIndigo` | `#4F46E5` |
| Secondary accents | `secondaryLavender` | `#A78BFA` |
| Cards | `surface` | `#FFFFFF` |
| Text | `textPrimary` | `#111827` |
| Discovery / capture success | `discoveryGold` / `captureSuccess` | `#F59E0B` |

---

## 6. Waveform exception

`IndigoCaptureWaveform` uses **indigo/lavender bars only** — no `Colors.black` or `#000000`. Pure black remains disallowed for UI except if a future dedicated audio visualizer explicitly requires it.

---

## 7. Post-migration checklist

- [x] Dark legacy cards migrated to light tokens
- [x] `themeMode: ThemeMode.light` on `MaterialApp`
- [x] `Colors.white` removed from non-token UI (heroes use `onPrimary`)
- [x] Record screen muted text uses `VoiceMemoryColors.textSecondary`
- [x] `flutter analyze` (see CI note below)

---

## 8. Recommended follow-ups (non-blocking)

1. Gradually replace `AppTheme.muted` / `AppTheme.foreground` with `Theme.of(context).textTheme` + `colorScheme` in secondary screens (settings, verification, journal).
2. Audit **Next.js web app** separately if parity with mobile rebrand is required (out of scope for this Flutter pass).
3. Add a `scripts/validate-theme-restraint.mjs` (mirror product-restraint) to fail CI on `Color(0xFF1` dark legacy patterns in `lib/widgets/`.

---

## 9. Analyze result

Run from `apps/voicememory_mobile`:

```bash
flutter analyze
```

**2026-05-25:** `flutter analyze` — **0 errors**, 22 issues (pre-existing infos/warnings in engines/tests; no theme-related failures). Fixed unused `app_theme.dart` import on `record_screen.dart` introduced during migration.
