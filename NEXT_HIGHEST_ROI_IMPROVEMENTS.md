# Next Highest-ROI Archive Improvements

Ranked after [ARCHIVE_V2_VALIDATION.md](./ARCHIVE_V2_VALIDATION.md) (Theory, Lifecycle, Change Feed, Deep Dive, Analyst on 5 personas × 50/100/200).  
**No new archive features** — quality and ranking only. **Do not build GPT-5 Archive Synthesis** until trust fixes below show up in re-validation.

**North star:** *ChatGPT helps you think. ArchiveMe shows what keeps repeating across your life.*

---

## How to read the rankings

Each item is scored **1–5** on:

| Dimension | What it means here |
|-----------|-------------------|
| **Retention** | Reason to reopen Archive (Change Feed, lifecycle arcs, drift) |
| **Trust** | Historian credibility — counters, primary, contradictions |
| **Shareability** | User would screenshot or send to a friend |
| **Willingness to pay** | Feels worth a subscription vs “I already know this” |

**Composite** = average of the four (used for order). Ties broken by Trust first, then Retention.

---

## Ranked improvements

| Rank | Improvement | Retention | Trust | Share | WTP | Composite | Rationale |
|------|-------------|-----------|-------|-------|-----|-----------|-----------|
| **1** | **Topical counter-evidence only** — never treat `hits == 0` as full-archive counter; require theme/keyword overlap or explicit `tensionOrContradiction` | 3 | **5** | 4 | **5** | **4.25** | Fixes 0% trait rows, inverted scores (relationship 67 counters on work belief), and off-topic debate quotes. Unblocks Theory, Analyst, Debate, Lifecycle confidence. |
| **2** | **Filter Analyst/Competing rows** — drop `confidencePercent == 0`, `evidenceCount < 3`, identity traits, “forming from reflections” | 3 | **5** | 3 | **5** | **4.0** | Removes generic-AI noise in every scenario; users stop seeing “You focus on career” beside real observations. |
| **3** | **Primary belief / Theory statement selection** — rank by evidence mass + recency + persona theme, not last `concreteObservation` only | **5** | **5** | 4 | **5** | **4.75** → *ordered #3 because it depends on #1 for stable scores* | Relationship fixture: work headline vs partner arc. Aligns V1, Theory hero, Lifecycle `current`, Deep Dive, Change Feed belief rows. **Highest product impact once counters are fixed.** |
| **4** | **Pass seeded high-confidence contradictions into Analyst + Change Feed** — love team/dread Slack, lonely/fine, rest/self-punishment, gut/data | 4 | **5** | **5** | 4 | **4.5** → *#4 in ship order* | Contradictions empty in 12/15 runs; Change Feed `contradictionsAppeared` stays 0. Surfaces “I didn’t know you saw that tension.” |
| **5** | **Debate: on-topic counter excerpts only** — same matcher as #1, scoped to belief under review | 3 | **5** | **5** | **5** | **4.5** → *#5 in ship order* | Best share moments today (fitness rest quote, burned-out boundary) — ruined when counter is a work rant in relationship persona. |
| **6** | **Emerging vs fading invariants** — never mark `isPrimary` belief as fading; dedupe same statement in both lists; fix declining label when series is flat | 4 | 4 | 2 | 3 | **3.25** | Founder @50: dominant beliefs “41→9 declining” undermines historian tone; hurts return visits. |
| **7** | **Lifecycle `current` = Theory statement** — single source of truth; retired beliefs from evolution only | 4 | 4 | 4 | 4 | **4.0** | Relationship @100: emotional `noLongerDetected` partner row vs work “current” — fix #3 first, then enforce lifecycle sync. |
| **8** | **Theory strengthen lines: quotes only** — suppress template lines when confidence ≥ 60%; use `ArchiveTheoryStrengthening` excerpts | 2 | 4 | 3 | 4 | **3.25** | Theory wins trust on counters; loses it on generic “Additional reflections over time…” at 70%. |
| **9** | **Blind spots: quote-backed or suppress** — drop “returning to theme” unless `BlindSpotLocalReview` has evidence | 2 | 4 | 2 | 3 | **2.75** | Obvious in all personas; low shareability. |
| **10** | **Change Feed: contradiction delta channel** — reuse #4 pairs for appeared/resolved since `baseline.timestamp` | **5** | 4 | 4 | 4 | **4.25** → *#10 because it depends on #4* | Change Feed already 15/15 “value” in harness; adding tensions completes “What Changed Since Last Review.” |
| **11** | **Evidence tap-through on Theory + Competing + Change Feed rows** — entry IDs on every conclusion | 4 | 4 | **5** | 4 | **4.25** | Shareability and paywall proof (“show me the receipts”). |
| **12** | **Extend fixtures to 200+ eligible + Level 3 gate test** — founder corpus length; verify L3 debate slots | 3 | 3 | 2 | 4 | **3.0** | Pay promise at 200 reflections not exercised. |

---

## Suggested ship order (trust → insight → polish)

```text
1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 10 → 9 → 11 → 12
```

**Week 1 (trust):** Counter matcher (#1), row filter (#2), primary selection (#3)  
**Week 2 (insight):** Contradictions pass-through (#4), debate scoping (#5), emerging/fading (#6)  
**Week 3 (V2 cohesion):** Lifecycle sync (#7), Theory quotes (#8), Change Feed contradictions (#10)  
**Week 4 (polish):** Blind spots (#9), evidence links (#11), fixtures/L3 (#12)

---

## What V2 proved (keep investing vs pause)

| Surface | Keep | Fix before scaling |
|---------|------|-------------------|
| **Archive Theory** | Counter transparency, low-confidence copy | Wrong statement, template strengthen lines |
| **Change Feed** | Monthly trends, belief % since review | Contradiction channel empty |
| **Belief Lifecycle** | `noLongerDetected` retired rows | `current` wrong when primary wrong |
| **Archive Debate** | On-topic counter-quotes | Off-topic counters |
| **GPT-5 synthesis** | **Pause** | Would amplify wrong primary fluently |

---

## What not to do yet

- Next.js Archive Change Feed port (explicitly deferred)
- New sections (chat, coaching, extra feeds)
- GPT-5-powered Archive Synthesis
- More belief/trait catalog entries without filter (#2)

---

## Re-validation gate (before GPT-5)

Re-run:

```bash
cd apps/voicememory_mobile
flutter test test/archive_quality_validation_test.dart
dart run tool/analyze_archive_v2_validation.dart
```

**Go criteria for synthesis exploration:**

| Metric | Current (V2) | Target |
|--------|--------------|--------|
| Scenarios with ≥1 surprise moment | 11/15 | ≥ 13/15 |
| `zeroConfidenceListed` in metrics | 15/15 | 0/15 |
| `counterExceedsSupport` on primary | ~15/15 | ≤ 3/15 |
| Relationship primary matches partner arc @100+ | No | Yes |
| Analyst contradictions on seeded personas | ~0 | ≥ 1 per seeded persona |
| Change Feed `contradictionsAppeared` when V1 has pairs | Rare | Aligned |

---

## Related docs

- [ARCHIVE_V2_VALIDATION.md](./ARCHIVE_V2_VALIDATION.md) — full grades and persona tables
- [ARCHIVE_QUALITY_REPORT.md](./ARCHIVE_QUALITY_REPORT.md) — V1/Analyst-only baseline
- [TOP_10_ARCHIVE_IMPROVEMENTS.md](./TOP_10_ARCHIVE_IMPROVEMENTS.md) — pre-V2 list (largely superseded by rankings above)
- [ARCHIVE_CHANGE_FEED_PLAN.md](./ARCHIVE_CHANGE_FEED_PLAN.md) — Change Feed design reference
