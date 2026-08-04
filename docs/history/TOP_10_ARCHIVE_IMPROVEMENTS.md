> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Top 10 Archive Improvements (Insight Quality)

Ranked by **expected impact** on retention, trust, and willingness to pay.  
Derived from [ARCHIVE_QUALITY_REPORT.md](./ARCHIVE_QUALITY_REPORT.md) — **no new features**, quality fixes and ranking logic only.

| Rank | Improvement | Retention | Trust | Willingness to pay | Rationale |
|------|-------------|-----------|-------|-------------------|-----------|
| **1** | **Filter competing/current candidates** — drop beliefs with `evidenceCount < 3`, 0% confidence, and identity traits unless they have real keyword support | ●●● | ●●●● | ●●●● | Removes “You focus on career” and “forming from reflections” noise that reads as generic AI and destroys pay intent. |
| **2** | **Fix counter-evidence matching** — do not count every non-matching entry as counter (`hits == 0`); require topical overlap or explicit tension/negation | ●●● | ●●●●● | ●●●● | Fixes inverted scores (boundaries 0% with 8 supports), makes confidence and debate trustworthy. |
| **3** | **Archive Debate: on-topic counter excerpts only** — score counters by shared theme/keywords with the belief under review; exclude work rants when debating relationship beliefs | ●● | ●●●●● | ●●●●● | Debate is the trust anchor; off-topic counters (relationship persona) feel fabricated. |
| **4** | **Primary belief selection** — weight by evidence mass + recency, not last `concreteObservation` only (fixes relationship @50/200 showing work pressure) | ●●●● | ●●●● | ●●●● | Wrong primary collapses V1, Deep Dive, and Analyst together. |
| **5** | **Emerging vs fading logic** — never label a top-ranked current belief as fading; require minimum bucket spread; cap duplicate trend on same statement | ●●● | ●●● | ●● | Founder @50 labeled dominant beliefs as fading — undermines historian credibility. |
| **6** | **Surface seeded contradictions in Analyst** — pass through high-confidence `ContradictionDetectionService` pairs (love team / dread Slack, rest / self-punishment, lonely / fine) | ●●● | ●●●● | ●●●● | Users expect “contradictions” section to deliver tension; empty section feels broken. |
| **7** | **Blind spots: quote-backed only** — replace “returning to theme” with `BlindSpotLocalReview` evidence quotes or suppress | ●● | ●●● | ●●● | Current blind spots are obvious and repeated across personas. |
| **8** | **Competing beliefs = meaningfully different hypotheses** — cluster by theme; dedupe near-identical statements; require ≥2 keyword overlap with distinct verb frames | ●●● | ●●●● | ●●●● | “Avoid cofounder” vs “postpone hiring” works; duplicate trends do not. |
| **9** | **Evidence links on every conclusion** — entry IDs on competing rows, emerging series month labels, tap-through from debate excerpts | ●●●● | ●●●● | ●●● | Historian tone requires citations; missing links block shareability. |
| **10** | **Level gating on eligible count** — document and test Level 3 at 200+ eligible; extend debate slots at L2/L3 only when counters exist | ●● | ●●● | ●●● | Paywall promise (“200 reflections”) should unlock visibly richer debate, not duplicate L2 with more noise. |

---

## Implementation priority (suggested)

**Ship first (trust):** 1 → 2 → 3 → 4  
**Ship second (insight):** 5 → 6 → 8  
**Ship third (polish):** 7 → 9 → 10  

---

## What not to do yet

Per product direction: **no new Archive features** (chat, coaching, extra sections). Quality gains come from tightening existing engines: catalog, confidence split, contradiction pass-through, and debate excerpt selection.

---

## Re-validation

After any fix above, re-run:

```bash
cd apps/voicememory_mobile
flutter test test/archive_quality_validation_test.dart
```

Compare `tool/output/archive_quality_raw.json` metrics: `genericPhraseHits`, `counterExceedsSupport`, `debatesMissingExcerpts` should trend to zero.

