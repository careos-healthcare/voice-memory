# Production Data Audit — ArchiveMe Mobile

**Date:** 2026-05-25  
**Scope:** `apps/voicememory_mobile` — eliminate sample/seed/fixture/demo archive data in production paths.

---

## Executive summary

Production `lib/` does **not** ship seeded journal entries. Journal storage initializes to `[]`. Insight engines now gate on **`ArchiveEvidenceGuard.minimumEvidenceCount`** (5 eligible reflections with ≥24-character transcripts).

Remaining non-production data lives only under **`tool/`** (visual audits, screenshot capture) and **`test/`**, gated by `VISUAL_AUDIT` / Flutter test harness.

---

## 1. Search results (by category)

### A. Tooling only — not user-visible in release

| File | Purpose | User-visible? | Safe for production? |
|------|---------|---------------|----------------------|
| `tool/full_visual_audit.dart` | `VisualAuditFixtures` seeds journal for screenshot audits | No (integration test + define) | Yes — never runs in release without `VISUAL_AUDIT` |
| `tool/ui_screenshot_audit.dart` | Seeds recording counts, sample entry routes | No | Yes |
| `tool/full_visual_audit_runner.dart` | Orchestrates audit fixture seeding | No | Yes |
| `tool/screenshot_capture.dart` | `_seedSampleJournalIfEmpty` for marketing captures | No | Yes |
| `test/journal_store_test.dart` | `sample()` / `sampleReflection()` helpers | No | Yes |
| `test/archive_evidence_test.dart` | Asserts no fake belief below threshold | No | Yes |
| `test/*.dart` (various) | Unit test fixtures | No | Yes |

### B. Dev overrides — inert in production

| File | Purpose | User-visible? | Safe for production? |
|------|---------|---------------|----------------------|
| `lib/dev/visual_audit_overrides.dart` | Record UI overrides for audits | No unless `VISUAL_AUDIT` or test env | Yes |
| `lib/dev/visual_audit_registry.dart` | Audit route registry | No | Yes |
| `lib/screens/record_screen.dart` | Reads `VisualAuditOverrides` when active | Only under audit flag | Yes |

### C. UI copy / placeholders (not archive data)

| File | Purpose | User-visible? | Safe for production? |
|------|---------|---------------|----------------------|
| `lib/screens/onboarding_screen.dart` | First-run educational copy | Yes (once) | Yes — not fabricated archive |
| `lib/widgets/placeholder_panel.dart` | Generic empty panel widget | Only if routed | Yes |
| `lib/screens/home_screen.dart` | Legacy home with `PlaceholderPanel` | No — not in `app_router` | Yes |
| `lib/models/entitlement.dart` | `source: 'local_placeholder'` billing field | Internal | Yes |
| `lib/screens/timeline_screen.dart` | `_EntryPreviewTile` = transcript preview UI | Yes | Yes — real entries only |
| `lib/features/archive_explanations/explanation_models.dart` | `preview` field = excerpt text | Yes | Yes — from real entries |
| `lib/audio/recording_service.dart` | `sampleRate: 44100` | N/A | Yes (audio API) |
| iOS `placeholder` storyboard | Interface Builder | N/A | Yes |

### D. Evidence-backed early archive (real user words, below full threshold)

| File | Purpose | User-visible? | Safe for production? |
|------|---------|---------------|----------------------|
| `lib/features/first_reflection/first_reflection_insights.dart` | Themes/phrases from user transcripts (1–4 reflections) | Yes when count &lt; 5 | Yes — keyword extraction, not seed data |
| `lib/features/immediate_archive_value/immediate_archive_value_engine.dart` | First/second/third recording comparisons | Yes in immediate mode | Yes — requires real entries |
| `lib/widgets/first_reflection_archive_section.dart` | Empty + early archive UI | Yes | Yes |
| `lib/widgets/immediate_discovery_card.dart` | `stillLearningCopy` honest fallback | Yes | Yes |

### E. Belief evolution “seed” (misnamed — not demo data)

| File | Purpose | User-visible? | Safe for production? |
|------|---------|---------------|----------------------|
| `lib/features/belief_changes/belief_evolution_service.dart` | `_seedFirstBelief` = first **version record** from user reflections | Yes when ≥ min evidence | Yes — gated by `archiveHasMinimumEvidence` |

### F. Production safeguards (added/updated)

| File | Purpose | User-visible? | Safe for production? |
|------|---------|---------------|----------------------|
| `lib/features/archive_evidence/archive_evidence_guard.dart` | Central `minimumEvidenceCount` + guards | Enforced in engines | Yes |
| `lib/features/archive_evidence/archive_evidence.dart` | Delegates to guard; belief requires minimum | Yes | Yes |
| `lib/widgets/archive_belief_summary_banner.dart` | Hidden until minimum evidence | Yes | Yes — fixed |
| `lib/features/weekly_story/weekly_story_engine.dart` | Uses eligible count guard | Yes | Yes — fixed |
| `lib/features/return_reason/return_reason_coordinator.dart` | Clears stale cards below threshold | Yes | Yes — fixed |

---

## 2. Engine null behavior (insufficient evidence)

| Engine | Returns null when |
|--------|-------------------|
| **Daily Discovery** | `!ArchiveEvidenceGuard.canSurfaceDiscovery` |
| **Archive Challenge** | `!ArchiveEvidenceGuard.canSurfaceDiscovery` |
| **Most Important Insight** | `!ArchiveEvidenceGuard.hasMinimumEvidence` |
| **Belief Under Review** | `!ArchiveEvidenceGuard.canSurfaceBelief` |
| **Archive Was Wrong** | `!ArchiveEvidenceGuard.hasMinimumEvidence` |
| **What Changed Today** | `!ArchiveEvidenceGuard.hasMinimumEvidence` |
| **Weekly Story** | `!ArchiveEvidenceGuard.canSurfaceWeeklyStory` |
| **Archive state belief** | `archiveBeliefFromReflections` → null below threshold |

---

## 3. Primary tab screens (fresh install)

| Screen | Fabricated content? | Empty-state copy |
|--------|---------------------|------------------|
| **Record** | No | Capture UI only |
| **Archive** | No | `FirstReflectionEmptyArchiveSection` / insufficient evidence message |
| **Discover** (`discover_screen`, `discover_yourself`) | No | “Return after another reflection…” / theme honesty |
| **Timeline** | No | Empty list |
| **Search** | No | No results messaging |
| **Account** | No | Session/sync only |

---

## 4. New install expectations

With **zero** journal entries:

- 0 recordings, discoveries, beliefs, themes, contradictions, chapters in insight engines
- Onboarding may show **product education** (not archive data)
- Persisted prefs (discover baseline, daily discovery pending) start empty; no default journal file

---

## 5. Honest empty-state examples (in app)

- “Your archive is still learning.” (`immediate_discovery_card.dart`)
- “Record a few more reflections.” (archive insufficient evidence copy)
- “No evidence yet.” / “No belief changes detected yet.” (Discover)
- “Your archive is waiting for its first memory.” (empty Archive)

---

## 6. Recommendations

1. Do not run `tool/run_ui_screenshot_audit.sh` against a production user data directory.
2. If audit seeds exist on a dev device (`screenshot-sample-*` ids), delete app storage or journal file.
3. Keep `VISUAL_AUDIT` out of release build defines.
