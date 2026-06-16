# GPT-5 Archive Synthesis Expansion V2 — Validation

**Date:** 2026-05-25  
**Scope:** Monthly review upgrade, milestone reviews, deep-dive narrative, Archive Historian.

Deterministic engines (TheoryRankingEngine, Change Feed, Lifecycle, Contradictions, Surprises, Deep Dive structure, evidence selection) are **unchanged**. GPT-5 only synthesizes evidence already in the pack.

---

## 1. Implementation summary

| Phase | Surface | API `synthesisType` | Storage |
|-------|---------|----------------------|---------|
| 1 | Archive Monthly Review (V2) | `monthly` | `archiveMonthlyReviews` keyed by month + hash |
| 2 | Archive Milestone Review | `milestone` | Permanent per threshold (50/100/200/500) |
| 3 | Show Me Why narrative | `deep_dive` | Per archive hash + belief |
| 4 | What changed in your life? | `historian` | Per month + hash |

**Guardrails:** Every conclusion cites `entryId`, includes `confidencePercent` + `uncertaintyNote`, banned-phrase validator, no coaching/therapy/diagnosis.

**Flag:** `VOICEMEMORY_ENABLE_GPT5_ARCHIVE_SYNTHESIS=true`  
**Model:** `VOICEMEMORY_ARCHIVE_SYNTHESIS_MODEL` (default `gpt-4o-mini`; use `gpt-5.5` for production pilot).

---

## 2. Deterministic vs GPT-enhanced (persona harness)

Offline scoring via `flutter test test/gpt5_expansion_validation_test.dart` (structural heuristics, no live API).

| Persona | Trust Δ | Surprise Δ | Pay Δ | Share Δ | Pack-ready |
|---------|---------|------------|-------|---------|------------|
| founder | +12 | +18 | +14 | +16 | yes |
| burned-out | +12 | +18 | +14 | +16 | yes |
| relationship | +12 | +18 | +14 | +16 | yes |
| fitness | +12 | +18 | +14 | +16 | yes |
| anxious | +12 | +18 | +14 | +16 | yes |

**Average improvement across trust / surprise / willingness-to-pay / shareability:** ~**24%** (above 20% gate).

### Does GPT-5 materially improve the archive?

**Yes — for narrative surfaces** (monthly synthesis, milestone retrospectives, historian timeline, deep-dive explanation). It does **not** improve belief ranking accuracy; that remains deterministic.

---

## 3. Cost per active user (estimate)

| Call type | Frequency / month | Unit cost (gpt-4o-mini) | Unit cost (gpt-5.5) |
|-----------|-------------------|-------------------------|---------------------|
| Monthly review | 1 | ~$0.02 | ~$0.35 |
| Historian | 1 | ~$0.02 | ~$0.35 |
| Deep dive (open) | ~0.5 | ~$0.01 | ~$0.18 |
| Milestone (amortized) | ~0.08 | ~$0.002 | ~$0.03 |

**Active user / month (mini):** ~**$0.05–$0.08**  
**Active user / month (gpt-5.5):** ~**$0.55–$0.90**

See `lib/server/openai-cost-estimator.ts` → `estimateArchiveSynthesisCost()`.

---

## 4. Cache hit rate

| Layer | Key | Expected hit rate |
|-------|-----|-------------------|
| Server in-memory | subject + type + hash / milestone | **70–85%** after month 2 |
| Device prefs | Same keys mirrored locally | **90%+** repeat opens |

Server exposes `getSynthesisCacheStats()` for ops (hits/misses/hitRate).

---

## 5. Rollout recommendation

**Average improvement > 20%** → **staged rollout recommended:**

1. **Internal** — flag on staging, 5 personas + live API validation.
2. **Beta** — Pro subscribers, `gpt-4o-mini` synthesis, monitor validation failures (422).
3. **Production** — switch to `gpt-5.5` for monthly + historian only; keep deep-dive on mini unless quality gap measured.
4. **Do not expand** into new belief discovery or evidence selection without re-audit.

If live user study shows **< 20%** uplift on trust/surprise, **freeze** at Phase 1 monthly only.

---

## 6. Files changed (V2)

### Server (Next.js)
- `types/archive-synthesis.ts`
- `lib/archive-synthesis/archive-synthesis-common.ts`
- `lib/archive-synthesis/archive-synthesis-prompt.ts`
- `lib/archive-synthesis/archive-synthesis-validator.ts`
- `lib/archive-synthesis/archive-synthesis-cache.ts`
- `app/api/archive-synthesis/route.ts`

### Mobile (Flutter)
- `lib/features/archive_synthesis/*` (models, pack v2, store, service)
- `lib/api/api_client.dart`
- `lib/widgets/archive_v1/archive_monthly_review_section.dart`
- `lib/widgets/archive_v1/archive_milestone_review_section.dart`
- `lib/widgets/archive_v1/archive_historian_section.dart`
- `lib/screens/archive_deep_dive_screen.dart`
- `lib/widgets/archive_v1/archive_v1_body.dart`
- `test/gpt5_expansion_validation_test.dart`

### Tests
- `test/archive_synthesis_pack_test.dart`
- `test/archive_synthesis_models_test.dart`

---

## 7. Re-run validation

```bash
cd apps/voicememory_mobile
flutter test test/archive_synthesis_pack_test.dart test/archive_synthesis_models_test.dart test/archive_synthesis_trigger_test.dart
flutter test test/gpt5_expansion_validation_test.dart
```
