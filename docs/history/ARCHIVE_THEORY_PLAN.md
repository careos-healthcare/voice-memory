# Archive Theory V1 — plan

## Goal

Replace user-facing **belief** framing with **“The Archive’s Current Theory”** — a historian-style working hypothesis backed by evidence counts, not coaching or new AI.

## Non-goals

- New LLM routes or generated copy
- Replacing internal `DiscoverBeliefEngine` / Deep Dive identifiers (belief text remains the hypothesis source)

## Confidence

Reuse **`ArchiveAnalystConfidenceEngine`** (`archive_analyst_confidence_engine.dart`):

- `splitEntries()` → supporting / counter counts
- `score()` → 0–100 with volume, consistency, recency, contradiction penalty, stale modifier

**Confident threshold:** 60% (same band as Analyst/V1 contradiction gates).

When `confidencePercent < 60`:

1. Show **“The archive is not yet confident.”**
2. Show current confidence
3. Show **missing evidence** line (heuristic from split state)
4. Show **what would strengthen** bullets (template only)

## Module (`apps/voicememory_mobile/lib/features/archive_theory/`)

| File | Role |
|------|------|
| `archive_theory_models.dart` | `ArchiveCurrentTheory`, `ArchiveTheoryStrengthening` |
| `archive_theory_copy.dart` | User-facing strings |
| `archive_theory_engine.dart` | Build theory from statement + entries + contradiction max |
| `archive_theory_strengthening.dart` | Missing-evidence + strengthen hints (no AI) |

## UI

| File | Role |
|------|------|
| `lib/widgets/archive_v1/archive_theory_hero_card.dart` | Hero card (replaces belief hero in `ArchiveV1Body`) |

## Integration

- `ArchiveV1Builder` builds `ArchiveCurrentTheory` after belief card; aligns `ArchiveV1Belief` confidence/evidence with theory for Deep Dive parity
- `ArchiveV1View.theory` + `showTheoryHero`
- `ArchiveV1Copy` — deprecate belief hero title in UI (theory copy used instead)

## Tests

- `test/archive_theory_engine_test.dart` — scoring, threshold, strengthening hints
- `test/archive_v1_builder_test.dart` — theory present when V1 builds

## Copy (V1)

- Title: **The Archive's Current Theory**
- Low confidence lead: **The archive is not yet confident.**
- Body: **The archive needs more evidence before reaching a strong conclusion.**
