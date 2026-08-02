# Archive V1 — Test Plan

**Date:** 2026-06-03  
**Scope:** Archive tab moat (belief hero, evolution, contradictions, blind spots, evidence trail)

---

## Automated tests

```bash
cd apps/voicememory_mobile
flutter test test/archive_v1_builder_test.dart
flutter test test/archive_evidence_test.dart
flutter analyze lib/features/archive_v1 lib/widgets/archive_v1 lib/screens/archive_evidence_trail_screen.dart lib/screens/archive_belief_screen.dart
```

| Test | Expectation |
|------|-------------|
| `ArchiveThemeGapEngine` — below min | No gap cards |
| `ArchiveThemeGapEngine` — importance + low % | Gap with you say / but |
| `ArchiveV1Builder` — no min evidence | `belief == null` |
| `ArchiveV1Builder` — 5 long entries | `belief` + confidence + count |

---

## Manual QA — zero recordings

| Step | Action | Expected |
|------|--------|----------|
| 1 | Fresh install → Archive tab | `FirstReflectionEmptyArchiveSection` |
| 2 | — | No belief hero, no contradictions |

---

## Manual QA — 1–4 recordings (immediate mode)

| Step | Expected |
|------|----------|
| Archive | `InstantArchiveBeliefCard`, immediate sections — **not** V1 hero |
| Evidence trail | Not offered from hero (no min evidence) |

---

## Manual QA — 5+ eligible recordings (V1)

| # | Check | Pass criteria |
|---|-------|---------------|
| 1 | Belief hero visible | Title “Your Archive Currently Believes”, quoted belief, confidence %, evidence count, relative updated |
| 2 | Tap hero / CTA | Opens **Evidence Trail** |
| 3 | Evidence trail | Belief quote, supporting excerpts (real), evolution timeline if versions exist, back works |
| 4 | Then → Now | THEN and NOW blocks, first/latest dates, supporting count |
| 5 | Contradictions | Only if confidence ≥ 60; You say / But layout; no items with 0 recordings |
| 6 | Blind spots | Only if confidence ≥ 60; cites recording count |
| 7 | No fake data | No `audit-entry-*` or pre-seeded rows |
| 8 | Pull to refresh | Rebuilds V1 after new recording |

---

## Manual QA — 5+ recordings, short transcripts

| Expected |
|----------|
| `We need more evidence` panel — no belief hero |

---

## Regression

| Area | Check |
|------|-------|
| Record tab | Still saves entries |
| Discover tab | Unchanged |
| Timeline / Search | Empty states intact |
| Entry detail | Opens from evidence trail |

---

## Screens requiring QA review

1. **Archive** (`/archive-belief`) — primary V1 stack  
2. **Evidence Trail** (`/archive-evidence-trail`) — new  
3. **Entry detail** (`/entry/:id`) — from trail / contradictions / blind spots  
4. **Archive** immediate mode (1–4 entries) — unchanged path  

---

## Files changed (implementation)

### New

- `lib/features/archive_v1/archive_v1_copy.dart`
- `lib/features/archive_v1/archive_v1_models.dart`
- `lib/features/archive_v1/archive_v1_builder.dart`
- `lib/features/archive_v1/archive_theme_gap_engine.dart`
- `lib/design/archive_relative_date.dart`
- `lib/widgets/archive_v1/archive_belief_hero_card.dart`
- `lib/widgets/archive_v1/archive_belief_evolution_then_now.dart`
- `lib/widgets/archive_v1/archive_v1_contradictions_section.dart`
- `lib/widgets/archive_v1/archive_v1_blind_spots_section.dart`
- `lib/widgets/archive_v1/archive_v1_body.dart`
- `lib/screens/archive_evidence_trail_screen.dart`
- `test/archive_v1_builder_test.dart`
- `ARCHIVE_V1_PLAN.md`
- `ARCHIVE_V1_TEST_PLAN.md`

### Modified

- `lib/screens/archive_belief_screen.dart` — V1 primary layout when evidence threshold met  
- `lib/router/app_router.dart` — `/archive-evidence-trail` route  

---

*End of test plan.*
