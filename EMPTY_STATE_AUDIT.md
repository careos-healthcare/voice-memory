# Empty State Audit — ArchiveMe Flutter (`apps/voicememory_mobile`)

**Date:** 2026-05-25  
**Scope:** Sample / demo / mock / seeded / hardcoded archive data; new-user empty experience  
**Method:** Repository-wide search (keywords + `List.generate`, fixture helpers), screen-by-screen review of production routes, cross-check with `PRODUCTION_DATA_AUDIT.md`  
**Constraint:** Audit only — no code changes.

---

## Executive summary

| Verdict | Detail |
|--------|--------|
| **Journal storage** | Fresh install writes `[]` — no bundled archive entries (`journal_store.dart` L18–20). |
| **Production `lib/`** | No `createDemoData`, `populateTestData`, `mockRepository`, or `Mock*` / `Demo*` Dart types. Seeded journals exist only under `tool/` and `test/`. |
| **Brand-new user (0 reflections)** | Archive and Timeline show honest empty states. **Discover Yourself** shows copy that implies the archive is already noticing patterns, plus a progress hero with zero metrics. |
| **After 2+ reflections** | **Updates** auto-creates and persists a synthetic in-app notification — users can believe the app “already had” updates. |
| **Engines** | Insight/evolution copy can read like analytics (e.g. “work stress”, “Nothing notable has shifted”) but is driven from user transcripts, not fixture data — still risky UX below evidence thresholds. |

**Related docs:** `apps/voicememory_mobile/PRODUCTION_DATA_AUDIT.md`, `REBRAND_AUDIT.md`

**Out of scope (separate product):** Next.js web app has explicit demo mode (`app/demo/page.tsx`, `lib/demo-mode`) — not shipped in the Flutter binary.

---

## 1. Search methodology

### 1.1 Keyword sweep

Searched `apps/voicememory_mobile` for: `sample`, `demo`, `mock`, `fake`, `testData`, `dummy`, `seed`, `example`, `preview`, `placeholder`, hardcoded memories/archive entries.

### 1.2 Structural patterns

Searched for: `List.generate(`, `initialData`, `seededData`, `createDemoData`, `populateTestData`, `populateSampleData`, `fakeEntries`, `fakeRecordings`, `mockRepository`, `Mock*`, `Demo*`.

**Result:** No matches for demo-population helpers in `lib/`. `List.generate` in `lib/` is UI-only (waveform bars, reputation grid, updates list rendering). Test/tool directories contain extensive `List.generate` fixtures.

---

## 2. Production path occurrences (`lib/`)

| File | Line(s) | What is shown | Production-safe? | Recommended replacement |
|------|---------|---------------|------------------|-------------------------|
| `lib/storage/journal_store.dart` | 18–20 | New journal file → `[]` | **Yes** | Keep |
| `lib/screens/updates_screen.dart` | 25–36 | If theory notifications empty **and** ≥2 eligible entries, injects `local-1` “Archive growing” / “compare themes”, persists to prefs | **No** (synthetic notification) | Only surface notifications from real engine events; never write placeholder rows to prefs |
| `lib/screens/updates_screen.dart` | 65–66 | Empty list → “No updates yet.” | **Yes** | Keep |
| `lib/widgets/first_reflection_archive_section.dart` | 124–151 | `FirstReflectionEmptyArchiveSection` — waiting for first memory | **Yes** | Prefer unified copy (see §5) |
| `lib/widgets/first_reflection_archive_section.dart` | 11–119 | `FirstReflectionArchiveSection` — themes/phrases from user entries (1–4) | **Yes** (unused in router) | Wire only with real entries, or delete dead widget |
| `lib/screens/archive_belief_screen.dart` | 173–174 | `reflectionCount == 0` → empty section | **Yes** | Align headline with §5 canonical copy |
| `lib/screens/archive_belief_screen.dart` | 194–214 | 1–4 reflections → immediate value + optional living quick view | **Caution** | Gate bold “noticed/pattern” language on transcript quality |
| `lib/screens/archive_belief_screen.dart` | 291–305 | ≥1 entry, &lt; min evidence → `changeSummary`, themes, watch | **Caution** | Hide `changeSummary`/watch until `hasMinimumEvidence` |
| `lib/features/archive_state_object/archive_state_object.dart` | 89–91 | Default `changeSummary`: “Nothing notable has shifted since your last visit.” | **Caution** | Use only when `hasMinimumEvidence`; else empty-state copy |
| `lib/features/archive_state_object/archive_state_object.dart` | 58–70 | `watchItem` nudges to record more when below threshold | **Yes** | Keep |
| `lib/features/archive_evolution/archive_evolution_engine.dart` | 109–110 | Headline e.g. “work is your biggest source of stress” from real theme comparison | **Yes** (not seeded) | Never show without evidence guard + user themes |
| `lib/features/archive_evolution/archive_evolution_copy.dart` | 3 | Comment “example bodies” — documentation only | **Yes** | — |
| `lib/features/belief_evolution/belief_evolution_service.dart` | 33–50, 141+ | `_seedFirstBelief` — first belief **version** from user reflections | **Yes** | Rename to `_initialBeliefFromReflections` (clarity) |
| `lib/features/discover/discover_models.dart` | 17–24 | `emptyStateMessage` for Discover modes | **Yes** | Tighten `empty` message (§5) |
| `lib/screens/discover_yourself_screen.dart` | 136–140 | Static lead: “Your archive is beginning to notice patterns.” | **No** (0 entries) | Show only when `entries.isNotEmpty`; else §5 copy |
| `lib/screens/discover_yourself_screen.dart` | 155–161 | `ArchiveProgressIdentityCard` with all zeros | **Caution** | Collapse hero until first recording |
| `lib/widgets/archive_progress_identity_card.dart` | 62–102 | “Your Archive” + 0 metrics + “View Growth” | **Caution** | Disable “View Growth” / hide card at 0 |
| `lib/screens/timeline_screen.dart` | 133–155 | Empty timeline + CTA | **Yes** | Optional: match §5 wording |
| `lib/screens/search_screen.dart` | 282–286 | Idle: “Nothing found yet. Search transcripts…” | **Caution** | “No recordings yet” when index empty; search hint when idle |
| `lib/screens/search_screen.dart` | 495–528 | Section empty messages (recent, themes, belief) | **Yes** | Keep |
| `lib/screens/journal_screen.dart` | 60–69 | “No reflections yet.” | **Yes** | Keep |
| `lib/screens/discover_screen.dart` | 104–112 | No baseline / no changes copy | **Yes** | Keep |
| `lib/screens/blind_spots_screen.dart` | 104–118 | “Not enough reflections yet” | **Yes** | Keep |
| `lib/screens/identity_screen.dart` | 91–111 | Insufficient evidence → record CTA only | **Yes** | Keep |
| `lib/screens/onboarding_screen.dart` | 13–19, 53 | Product education slides; `ArchiveQuickExplainCard(reflectionCount: 0)` | **Yes** | Rebrand “ArchiveMe” → ArchiveMe |
| `lib/widgets/top_themes_section.dart` | 32–37 | No themes → explanatory muted text | **Yes** | Keep |
| `lib/widgets/memory_resurfacing_section.dart` | 86 | Empty → `SizedBox.shrink()` | **Yes** | Keep |
| `lib/widgets/instant_archive_belief_card.dart` | 76–77 | “Your archive is still learning about you.” | **Yes** | Keep for early recordings |
| `lib/widgets/immediate_discovery_card.dart` | — | `stillLearningCopy` fallback | **Yes** | Keep |
| `lib/dev/visual_audit_overrides.dart` | 16–20 | Record UI overrides when `VISUAL_AUDIT` or `FLUTTER_TEST` | **Yes** if release omits define | Document in release checklist |
| `lib/screens/record_screen.dart` | 412–420 | Applies audit overrides when active | **Yes** | Same |
| `lib/models/entitlement.dart` | 22 | `source: 'local_placeholder'` (billing metadata) | **Yes** | — |
| `lib/audio/recording_service.dart` | 116 | `sampleRate: 44100` (API) | **Yes** | — |
| `lib/widgets/archive_reputation_card_mobile.dart` | 72 | `List.generate(28)` UI dots | **Yes** | — |
| `lib/widgets/indigo_capture_waveform.dart` | 49 | Waveform bars | **Yes** | — |
| `lib/widgets/placeholder_panel.dart` | 5+ | Generic empty panel | **Yes** | Only used from legacy `home_screen` (not in shell) |
| `lib/screens/home_screen.dart` | 44 | `PlaceholderPanel` | **Yes** (unrouted) | — |
| `lib/widgets/archive_return_reason_card.dart` | 10+ | Return-reason UI | **Yes** (not mounted in production archive screen) | Wire with coordinator or remove |
| `lib/features/timeline/timeline_entry_display.dart` | 6 | Comment: no draft placeholders in titles | **Yes** | — |

---

## 3. Tooling & test paths (not production user journeys)

| File | Line(s) | What is shown | Production-safe? | Recommended replacement |
|------|---------|---------------|------------------|-------------------------|
| `tool/full_visual_audit.dart` | 15–63 | `VisualAuditFixtures.seedRecordingCount` — `audit-entry-*` synthetic transcripts | **Yes** (gated) | Never run on user devices; require `VISUAL_AUDIT` |
| `tool/screenshot_capture.dart` | 96–116 | `_seedSampleJournalIfEmpty` → `screenshot-sample-1` career transcript | **Yes** (tool only) | Same |
| `tool/ui_screenshot_audit.dart` | 898–1211 | Seeds counts, `example.com` email, sample routes | **Yes** | Same |
| `tool/full_visual_audit_runner.dart` | 209–363 | Orchestrates fixture seeding | **Yes** | Same |
| `test/journal_store_test.dart` | 18–43 | `sample()` / `sampleReflection()` | **Yes** | — |
| `test/archive_evidence_test.dart` | 38–62 | `List.generate` entries; asserts no fake belief | **Yes** | — |
| `test/*_test.dart` (20+ files) | various | `List.generate` journal fixtures | **Yes** | — |

---

## 4. Primary navigation — new user screen matrix

Default post-onboarding shell (`app_router.dart`): **Record**, **Archive**, **Discover Yourself**, **Timeline**, **Search**, **Account**.

### 4.1 Zero reflections (brand-new)

| Screen | Route | Fake recordings / beliefs / insights? | What user sees | Risk |
|--------|-------|--------------------------------------|----------------|------|
| Onboarding | `/onboarding` | No | Educational slides | Low |
| Record | `/record` | No | Capture UI; resurfacing hidden | Low |
| Archive | `/archive-belief` | No | `FirstReflectionEmptyArchiveSection` | **Low** |
| Discover Yourself | `/discover-yourself` | No seeded data | Progress hero **0/0/0**, static “beginning to notice patterns”, empty-mode banner | **High** (copy implies activity) |
| Timeline | `/timeline` | No | Empty story CTA | Low |
| Search | `/search` | No | “Nothing found yet…” idle state | Medium (wording) |
| Account | `/account` | No | Session/settings | Low |
| Updates | `/updates` (pushed) | No (0 entries) | “No updates yet.” | Low |
| Journal | `/journal` (deferred tool) | No | “No reflections yet.” | Low |
| Identity | `/archive-identity` | No | Record-more CTA | Low |
| Blind spots | `/blind-spots` | No | Not enough reflections | Low |
| Weekly story | `/weekly-story` | No | Engine returns null — card hidden | Low |

### 4.2 One to four reflections (immediate archive mode)

| Screen | Fake data? | What user sees |
|--------|------------|----------------|
| Archive | No — keyword extraction from **user** transcripts | `InstantArchiveBeliefCard`, `ImmediateArchiveValueSections`, optional `LivingArchiveQuickView` |
| Discover Yourself | No | Early insight mode banner; sections hidden until thresholds |
| Engines | No | May show “still learning” or thin-theme lines — not seeded |

### 4.3 Five+ reflections but below evidence guard (&lt;5 eligible long transcripts)

| Screen | Fake data? | What user sees |
|--------|------------|----------------|
| Archive (full layout) | No | `changeSummary`, `TopThemesSection`, `ArchiveWatchCardMobile` — can feel like analytics without a formed belief |
| Discover | No | “Return after another reflection…” or honest empty lines |

### 4.4 Two or more reflections — Updates auto-seed

| Screen | Fake data? | What user sees |
|--------|------------|----------------|
| Updates | **Yes — synthetic notification** | Persisted “Archive growing” item (not from push pipeline) |

---

## 5. Designed empty states (recommended copy)

Use one canonical voice for **zero reflections**:

> **No recordings yet.** Record your first thought to begin building your archive.

| Surface | Current (representative) | Recommended |
|---------|-------------------------|-------------|
| Archive home | “Your archive is waiting for its first memory.” | Canonical line above + single **Record** CTA |
| Timeline | “Your story begins with your first recording.” | Same canonical line |
| Journal | “No reflections yet.” | Align wording |
| Search (empty index) | “Nothing found yet. Search transcripts…” | “No recordings yet. Your search will include transcripts and themes after you record.” |
| Discover Yourself (0 entries) | Lead: “beginning to notice patterns” + 0-metric hero | Hide progress hero; lead = canonical line; show `DiscoverInsightMode.empty` banner only |
| Discover Yourself (empty mode) | “Record a few thoughts and your archive will begin noticing patterns.” | OK; optional tighten to canonical |
| Updates | “No updates yet.” | “No updates yet. Updates appear when your archive has enough to compare.” |
| Archive (insufficient evidence) | Counts + “will not invent beliefs…” | Keep — honest |
| Instant belief (early) | “Your archive is still learning about you.” | Keep |
| Themes section | “Themes will appear after reflections mention patterns…” | Keep |
| Identity | “Record N more reflections…” | Keep |

**BAD (implies existing analysis):**

- “Work stress pattern detected” (without user-backed detection)
- “Your archive is beginning to notice patterns” (with **zero** recordings)
- Auto-inserted “Archive growing” notification

**GOOD:**

- “No recordings yet. Record your first thought to begin building your archive.”
- “Your archive is still learning.” (after 1–2 short reflections)
- “Record 3 more reflections with enough spoken detail before beliefs appear.”

---

## 6. Occurrence index — `List.generate` / fixtures

| Location | Count | Role |
|----------|-------|------|
| `lib/widgets/archive_reputation_card_mobile.dart` | 1 | Decorative grid |
| `lib/widgets/indigo_capture_waveform.dart` | 1 | Waveform UI |
| `lib/screens/updates_screen.dart` | 1 | Renders notification list |
| `test/**/*.dart` | 80+ | Synthetic journal entries for unit tests |
| `tool/*.dart` | 10+ | Screenshot/visual audit seeding |

No `initialData`, `seededData`, `createDemoData`, `populateTestData`, `populateSampleData`, `fakeEntries`, `fakeRecordings`, or `mockRepository` in Dart sources.

---

## 7. Dead / unused empty-state widgets

| Widget | File | Wired? | Note |
|--------|------|--------|------|
| `FirstReflectionArchiveSection` | `first_reflection_archive_section.dart` | **No** | Early-archive UI; only `FirstReflectionEmptyArchiveSection` used |
| `ArchiveReturnReasonCard` | `archive_return_reason_card.dart` | **No** | Coordinator exists; card not on `ArchiveBeliefScreen` |

---

## 8. Web repository (Flutter audit context)

The Next.js app includes an explicit **demo mode** with seeded reflections (`app/demo/page.tsx`, `@/lib/demo-mode`). That does not affect the Flutter binary but **does** affect “entire repository” searches. Keep demo routes dev-only and never linked from production mobile builds.

---

## LAUNCH BLOCKERS

Screens or behaviors that can make a user believe the app **already contains archive data** (not merely that it *will* learn):

| Priority | Screen / behavior | File:line | Why it blocks |
|----------|-------------------|-----------|---------------|
| **P0** | **Discover Yourself** static subtitle with **0** recordings | `discover_yourself_screen.dart:136-140` | “Your archive is beginning to notice patterns” asserts ongoing analysis with an empty journal |
| **P0** | **Updates** synthetic notification | `updates_screen.dart:25-36` | Creates and **persists** a fake “Archive growing” update after 2 reflections — reads as pre-existing product activity |
| **P1** | **Discover Yourself** progress hero at 0 | `discover_yourself_screen.dart:155-161`, `archive_progress_identity_card.dart:62-111` | Full “Your Archive” dashboard with zeros still feels like an populated product surface; “View Growth” implies existing trajectory |
| **P1** | **Search** idle copy | `search_screen.dart:282-286` | “Nothing found yet” sounds like a failed search over existing content rather than an empty archive |
| **P2** | **Archive** below evidence threshold | `archive_belief_screen.dart:291-305`, `archive_state_object.dart:89-91` | “Nothing notable has shifted…” + theme/watch rows with few short recordings mimic analytics |
| **P2** | **Archive evolution** stress headline | `archive_evolution_engine.dart:109-110` | Example-class copy (“work… stress”) is harmful if shown without strong evidence (guard-dependent) |

### Not launch blockers (verified)

- No pre-seeded journal on install (`journal_store.dart`).
- Visual audit / screenshot seeds (`tool/`, `VISUAL_AUDIT`) — not in release paths.
- Onboarding slides — education, not fabricated entries.
- Timeline / Journal / Archive zero-state CTAs — honest empty archives.
- `FirstReflectionEmptyArchiveSection` — appropriate empty archive home.
- Memory resurfacing — hidden when no cards.
- Weekly story / daily discovery / surprise engines — return null when guards fail.

---

## 9. Release checklist (empty-state)

1. Fresh install → complete onboarding → confirm Archive, Timeline, Search, Discover show **no** recordings, beliefs, charts, or notifications.
2. Record 1 reflection → Archive shows learning copy, not seeded beliefs.
3. Record 2 reflections → open **Updates** → confirm **no** auto-created “Archive growing” row.
4. Release build **without** `--dart-define=VISUAL_AUDIT=true`.
5. Dev devices: delete app storage if `audit-entry-*` or `screenshot-sample-*` IDs exist from prior tool runs.

---

*End of audit.*
