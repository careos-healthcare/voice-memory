# GPT-5 Synthesis Pilot — plan

**Status:** Implemented behind flags — parallel layer only; does not replace Archive V1 engines.

## Flags

| Surface | Flag |
|---------|------|
| Mobile | `AppConfig.enableGpt5ArchiveSynthesis` — `--dart-define=ENABLE_GPT5_ARCHIVE_SYNTHESIS=true` |
| Server | `VOICEMEMORY_ENABLE_GPT5_ARCHIVE_SYNTHESIS=true` + `OPENAI_API_KEY` |

Model override: `VOICEMEMORY_ARCHIVE_SYNTHESIS_MODEL` (default `gpt-4o-mini` for pilot compatibility; production target `gpt-5.5`).

## Triggers (all required: eligible ≥ 50)

1. **Monthly review due** — no stored review for current `monthKey` (`YYYY-MM`, local timezone).
2. **Archive milestone** — eligible count newly crosses 50, 100, 200, or 500 (once per milestone).

No regeneration when `archiveHash` unchanged (same pack content).

## Cache key

`userId + monthKey + archiveHash`

- **Client:** `ArchiveMonthlyReviewStore` (prefs)
- **Server:** in-memory map (pilot); keyed by `subject` + month + hash

## Inputs (deterministic pack)

Built on-device from existing engines only:

- Archive Theory
- Belief Lifecycle
- Change Feed
- Contradictions, Blind Spots, Archive Surprises
- Evidence trails (excerpts from belief support + counters)

## Output — Archive Monthly Review

1. What Changed  
2. Emerging Theories  
3. Fading Theories  
4. Surprises  
5. Evidence For  
6. Evidence Against  

Each item: `statement`, `confidencePercent`, `uncertaintyNote`, `evidence[{ entryId, excerpt? }]`.

## UI

`ArchiveMonthlyReviewSection` — inserted in `ArchiveV1Body` after theory agreement; does not hide Change Feed / Surprises / Lifecycle.

## Estimates (100 eligible reflections, `gpt-5.5` @ $5/$30 per 1M)

| Metric | Typical | Heavy (200) |
|--------|---------|-------------|
| Input tokens | ~18K | ~30K |
| Output tokens (incl. reasoning) | ~14K | ~22K |
| **Cost / run** | **~$0.50** | **~$0.80** |
| **Latency (sync)** | 25–60s P50 | 45–90s P95 |
| **Cache savings** | ~100% cost on repeat open same month | Same |

With unchanged archive: **0 LLM calls** after first cached report.

## Reproduce

```bash
cd apps/voicememory_mobile
flutter test test/archive_synthesis_trigger_test.dart test/archive_synthesis_pack_test.dart
```

Server route (flag on): `POST /api/archive-synthesis` with session or capture token.
