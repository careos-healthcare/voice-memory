> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Topical Counter-Evidence V1 — Plan

**Date:** 2026-06-03  
**Goal:** Counter-evidence must come from the same topic as the theory and must oppose it — not unrelated archive volume.

---

## Problem

`ArchiveAnalystConfidenceEngine.splitEntries` treated any reflection with `hits == 0` as counter. Deep Dive preferred **zero** keyword overlap for “against” excerpts. Result: work transcripts counted against relationship beliefs; 0-support / 67+ counter rows.

---

## V1 rules

| # | Rule |
|---|------|
| 1 | **Remove** unconditional `hits == 0` ⇒ counter. |
| 2 | Counter entry must be **topically scoped**: same canonical theme as belief **OR** belief cluster (≥1 belief-keyword hit / shared theme with support) **OR** linked contradiction (`entryIds` or topical `tensionOrContradiction`). |
| 3 | Counter must **oppose** the theory: negation + keyword, tension field, contradiction link, or opposing sentiment (e.g. exhaustion belief vs team-love quote; discipline vs rest). |
| 4 | **Cap** counters used for scoring: `min(rawTopical, max(8, support × 2))`; when `support > 0` and `raw > support × 2`, set `counterExceedsSupportTwice` for copy warnings. |
| 5 | **One selector** (`TopicalCounterEvidence`) drives `splitEntries`, Deep Dive against excerpts, and Analyst debates (primary via Deep Dive). |

---

## Files

| File | Change |
|------|--------|
| `lib/features/archive_analyst/topical_counter_evidence.dart` | **New** — topical scope, opposition, cap |
| `lib/features/archive_analyst/archive_analyst_confidence_engine.dart` | Delegate counter bucket to topical selector |
| `lib/features/archive_deep_dive/archive_deep_dive_engine.dart` | Against excerpts from topical selector + contradictions |
| `lib/features/archive_theory/archive_theory_engine.dart` | Optional `contradictionEntryIds` |
| `lib/features/archive_v1/archive_v1_builder.dart` | Pass contradiction ids into theory build |
| `lib/features/archive_analyst/archive_analyst_engine.dart` | Pass contradiction ids into `splitEntries` |
| `lib/features/archive_theory/archive_theory_strengthening.dart` | Warn when `counterExceedsSupportTwice` |
| `test/topical_counter_evidence_test.dart` | **New** — scope, opposition, cap |
| `test/archive_analyst_confidence_test.dart` | Cross-theme not counted |
| `test/archive_quality_validation_test.dart` | `counterEvidenceRelevancePercent` ≥ 85% |
| `tool/analyze_topical_counter_relevance.dart` | **New** — harness reporter |

---

## Success criteria (post-implementation)

| Criterion | Result |
|-----------|--------|
| Counter-evidence relevance > 85% | **100%** (6/6 debate quotes with counters; `counterEvidenceRelevance` in raw JSON) |
| Remove `hits == 0` blanket counter | Done — `splitEntries` uses `TopicalCounterEvidence` only |
| Deep Dive + Debate same selector | Done — shared module + excerpt filter via `isRelevantCounterQuote` |
| Cap counter at 2× support | Done — `TopicalCounterCap` + `counterExceedsSupportTwice` copy |
| `counterExceedsSupport` inflation | **Reduced** — most scenarios no longer flag off-topic counter mass |

---

## Validation

```bash
cd apps/voicememory_mobile
flutter test test/topical_counter_evidence_test.dart
flutter test test/archive_analyst_confidence_test.dart
flutter test test/archive_quality_validation_test.dart
dart run tool/analyze_topical_counter_relevance.dart
dart run tool/analyze_archive_v2_validation.dart
```

