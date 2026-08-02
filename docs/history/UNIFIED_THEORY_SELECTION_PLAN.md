# Unified Primary Theory Selection — Plan

**Date:** 2026-06-03  
**Goal:** One ranked primary theory consumed by Archive hero, Deep Dive, Lifecycle, Analyst, Change Feed context, and GPT-5 Monthly Review pack — no new surfaces.

---

## Problem

| Surface | Old selection |
|---------|----------------|
| Theory hero | Latest `concreteObservation` via Discover card |
| Analyst primary | Highest confidence among catalog candidates |
| Deep Dive | V1 `belief` (mirrored hero) |
| Lifecycle | `theory?.statement` or card |
| GPT-5 pack | `view.theory` |
| Change Feed | All catalog deltas (OK); hero unrelated |

Trust breaks when relationship persona shows **work** hero (0 ev) while Analyst shows **partner**.

---

## Solution: `TheoryRankingEngine`

Single rank pass over `ArchiveAnalystBeliefCatalog` candidates.

### Score components (rankScore 0–100)

| Component | Weight | Source |
|-----------|--------|--------|
| Evidence volume | 0–35 | `supporting.length` |
| Consistency | 0–20 | `split.consistencyRatio` |
| Recency | 0–15 | `split.recencyRatio` |
| Contradiction relevance | 0–10 | Keyword overlap with V1 contradictions |
| Surprise value | 0–10 | Overlap with Archive Surprises observations |
| Counter quality | 0–10 | Topical counter ratio; penalize raw ≫ 2× support |

Display **confidence** remains `ArchiveAnalystConfidenceEngine.score` on the winner.

### Reject (not eligible for primary)

- Trait templates (`You focus on…`, `You express…`, etc.)
- Placeholder / gathering-evidence copy
- Confidence **< 15%**
- Supporting evidence **< 3**
- Empty or very short statements

### Output

- `primaryTheory` — top eligible `RankedTheory`
- `secondaryTheories` — next eligible (up to 5)

Stored on `ArchiveV1View.theoryRanking` and used everywhere.

---

## Wiring (no new UI)

| Consumer | Change |
|----------|--------|
| `ArchiveV1Builder` | Rank → build theory/belief/lifecycle/thenNow from `primaryTheory` |
| `ArchiveAnalystEngine` | `isPrimary` = matches `v1.theoryRanking.primaryTheory` |
| `ArchiveDeepDiveEngine` | Unchanged — reads V1 belief/theory (already aligned) |
| `ArchiveSynthesisPackBuilder` | Unchanged — reads `view.theory` |
| `ArchiveChangeFeedEngine` | Unchanged — deltas for all candidates; hero aligned via V1 |

---

## Validation

`test/archive_primary_theory_validation_test.dart`:

1. Relationship persona: hero contains partner/relationship (not work-delivery headline)
2. `theoryMatchesPrimary` — 15/15
3. Deep Dive `beliefStatement` == theory statement
4. Lifecycle `current.statement` == theory when present
5. Theory `evidenceCount >= 3` and `confidencePercent >= 15` when hero shown
6. GPT-5 pack theory statement == V1 theory

Harness: extend `archive_quality_validation_test` metrics + assert primary theory gates.

---

## Success criteria

- **Hero theory = top ranked theory** (`heroEqualsTopRankedTheory` in harness)
- Relationship persona fixed (partner belief, not work delivery)
- Hero = Analyst primary = Deep Dive = GPT-5 theory statement
- 0-ev / 0% hero theories = 0
- `theoryMatchesPrimary` true for all 15 scenarios
- Trust metrics improve vs `PRIMARY_THEORY_AUDIT.md` baseline

---

## Post-implementation results (2026-06-03)

| Metric | Before (audit) | After |
|--------|----------------|-------|
| `theoryMatchesPrimary` | 9/15 | **15/15** |
| Relationship work hero | 3/3 sizes | **0/3** |
| Hero 0-ev | 3/15 | **0/15** |
| `unifiedSurfaceMismatch` | — | **0/15** |

Reproduce:

```bash
cd apps/voicememory_mobile
flutter test test/theory_ranking_engine_test.dart
flutter test test/archive_primary_theory_validation_test.dart
flutter test test/archive_quality_validation_test.dart
dart run tool/analyze_archive_v2_validation.dart
```
