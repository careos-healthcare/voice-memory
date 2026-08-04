> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Trait Pollution Removal — Plan

**Date:** 2026-06-03  
**Goal:** Users never see 0% rows, 0-evidence rows, identity trait templates, or unsupported competing beliefs.

---

## Pollution sources (audit)

- `IdentityEngine` → `ArchiveAnalystBeliefCatalog` adds `You focus on career` style traits
- `splitEntries` gives traits **0 support** → **0%** confidence in Analyst lists
- Secondary **Current / Competing / Emerging / Fading** slots still rendered in UI

Theory hero was partially fixed by `TheoryRankingEngine`; Analyst lists were not.

---

## Filter rules (`ArchiveBeliefVisibility`)

Reject from **user-visible** lists when any of:

| Rule | Threshold |
|------|-----------|
| Low confidence | `< 15%` |
| Low evidence | `< 3` supporting recordings |
| Trait template | `You focus on…`, `You express confidence`, `You avoid conflict`, gathering-evidence copy |
| Unsupported | fails confidence **or** evidence **or** template |

---

## Apply to

| Surface | Change |
|---------|--------|
| **Theory hero** | `showTheoryHero` + `ArchiveTheoryEngine` guard |
| **Analyst Current** | Only visible scored beliefs |
| **Analyst Competing** | Visible only; `isPrimary` by id |
| **Analyst Emerging / Fading** | Visible scored only |
| **Analyst Debates** | Visible beliefs only |
| **Deep Dive** | Null when primary not visible |
| **Catalog** | Do not ingest identity trait templates |

`TheoryRankingEngine` reuses same visibility helper.

---

## Validation

Extend `archive_quality_validation_test.dart`:

- `visibleZeroConfidenceRows == 0` (current, emerging, fading, competing)
- `visibleZeroEvidenceRows == 0`
- `visibleTraitTemplates == 0`

---

## Success criteria

- Visible 0% rows = **0**
- Visible 0-evidence rows = **0**

---

## Post-implementation results (2026-06-03)

| Metric | Before (audit) | After |
|--------|----------------|-------|
| Visible 0% rows (Current/Emerging/Fading/Competing) | **43/80** listed | **0** |
| Visible 0-evidence rows | **42/80** | **0** |
| Trait templates in UI lists | **38/80** | **0** |
| `zeroConfidenceListed` in harness metrics | 15/15 scenarios | **0/15** |

Reproduce:

```bash
cd apps/voicememory_mobile
flutter test test/archive_belief_visibility_test.dart
flutter test test/archive_quality_validation_test.dart
dart run tool/analyze_archive_v2_validation.dart
```

