# Archive V2 Validation — Theory, Lifecycle, Change Feed

**Date:** 2026-05-25  
**Scope:** Real-world-style validation only — no new archive features, no Next.js port, no GPT-5 synthesis.  
**Method:** 5 synthetic personas × 50 / 100 / 200 reflections; engines run on-device with **simulated mid-archive review baseline** (~45% through eligible timeline) for Change Feed.

## Reproduce

```bash
cd apps/voicememory_mobile
flutter test test/archive_quality_validation_test.dart
dart run tool/analyze_archive_v2_validation.dart
dart run tool/summarize_archive_quality.dart   # optional human-readable dump
```

| Artifact | Path |
|----------|------|
| Personas | `test/support/archive_quality_personas.dart` |
| Raw outputs | `tool/output/archive_quality_raw.json` |
| Grading summary | `tool/output/archive_v2_validation_summary.json` |
| Prior V1-only report | [ARCHIVE_QUALITY_REPORT.md](./ARCHIVE_QUALITY_REPORT.md) |

**Fixture note:** Personas cap at ~151–185 eligible entries; “200 reflections” means “use full fixture.” Level 3 (200+ eligible) was not reached.

---

## Executive verdict

| Question | Verdict |
|----------|---------|
| **Closer to “what keeps repeating across your life”?** | **Partially yes** at 100–200 reflections for 3/5 personas when outputs use **verbatim observations** and **Change Feed / Theory** show drift over time. Still feels like ChatGPT-theme labeling when traits, blind spots, or wrong primaries appear. |
| **Genuinely surprising & evidence-backed?** | **Sometimes** — 11/15 scenarios had ≥1 automated “surprise” signal; **5/15** had none. Best surprises: honest Theory confidence collapse (founder @200), debate counter-quotes (burned-out, fitness), partner belief “no longer detected” (relationship @100), belief weakened since review (Change Feed, most L2+ runs). |
| **Theory more trustworthy than Belief?** | **Yes in framing** — 15/15 scenarios expose counter counts, low-confidence copy, and strengthen gaps. **No in substance** when primary statement is wrong (relationship) or still a trait row. |
| **Lifecycle emotional impact?** | **Moderate** — 8/15 scenarios; strongest when a **retired** belief is marked `noLongerDetected`. Weak at 50 reflections (single-phase “first appearance” only). |
| **Change Feed perceived value?** | **High in harness** — 15/15 scenarios show non-empty deltas with simulated baseline; theme trends and belief confidence deltas read as “since last visit.” |
| **Build GPT-5 Archive Synthesis now?** | **No.** Trust and ranking fixes will move the product more than a new model layer. Re-validate after counter-evidence, primary selection, and contradiction pass-through. |

**Positioning check**

> ChatGPT helps you think. ArchiveMe shows what keeps repeating across your life.

| Signal | ChatGPT-like (bad) | Historian-like (good) |
|--------|-------------------|----------------------|
| Dominant outputs | Theme labels (“career”), traits (“You focus on…”), template strengthen lines | Verbatim user observations with counts |
| Time | Single-session summary | Then/now, monthly mention series, weakened since review |
| Honesty | Confident generic claims | Theory at 25% with 24 counters named |

V2 surfaces **add historian signals** (Change Feed trends, Theory counter transparency, Lifecycle retirement). **Legacy Analyst noise** (0% rows, off-topic counters, empty contradictions) still breaks trust before synthesis would help.

---

## Grading key

| Grade | Meaning |
|-------|---------|
| **Obvious** | Restates latest reflection, theme loop, or wrong primary. |
| **Interesting** | Connects evidence clusters the user might not have named. |
| **Surprising** | Non-trivial tension, honest confidence collapse, or counter-quote that reframes the primary. |

---

## Aggregate scorecard (15 scenarios)

| Surface | Obvious | Interesting | Surprising | Typical failure mode |
|---------|---------|-------------|------------|----------------------|
| **Archive Theory** | 4 | 9 | 1 | Same wrong statement as V1; template strengthen lines at high confidence |
| **Belief Lifecycle** | 7 | 7 | 1 | Only `firstAppearance` at 50; “current” follows wrong primary |
| **Change Feed** | 0 | 9 | 6 | Belief deltas strong; contradictions appeared often 0 despite V1 gaps |
| **Deep Dive** | 8 | 5 | 2 | Relationship persona misaligned at all sizes |
| **Archive Analyst** | 3 | 9 | 3 | 0% competing rows; seeded contradictions missing; fading mislabels |

**Automated rates** (`archive_v2_validation_summary.json`):

- Theory framing more trustworthy than bare Belief: **15/15** (counter/strengthen/honest-low-confidence UI data present)
- Lifecycle emotional impact (retired/weakening/events): **8/15**
- Change Feed adds value: **15/15**
- ≥1 surprise moment: **11/15**

---

## Specific measurements

### 1. Did Theory feel more trustworthy than Belief?

**Yes for UX honesty, not always for correctness.**

Theory reuses the same statement as the belief hero but adds:

- `counterEvidenceCount` visible in data model (e.g. founder @200: **24 counters**, confidence **25%**)
- `missingEvidenceMessage`: *“Strong contradictions in the archive are pulling confidence down.”*
- `isConfident: false` when below threshold

| Persona | Size | Theory confidence | Counters | Trust read |
|---------|------|-----------------|----------|------------|
| Founder | 200 | 25% | 24 | **Surprising** — user sees the archive doubting the headline |
| Burned-out | 50 | 47% | 10 | **Interesting** — calibrated, not overconfident |
| Relationship | 100 | 0% | 67 | **Breaks trust** — honest about thin support but **wrong statement** (work pressure, 0 supporting recordings) |
| Fitness | 100+ | 60–70% | low | **Obvious** — stable sleep/discipline arc, expected |

**Gap:** High-confidence Theory still ships generic strengthen lines (*“Additional reflections over time…”*) instead of only quote-backed lines. Belief hero did not show counters at all — Theory wins on transparency.

### 2. Did Lifecycle create emotional impact?

**Inconsistent; best when evolution retires a prior self-narrative.**

| Persona | Size | Lifecycle highlight | Impact |
|---------|------|---------------------|--------|
| Relationship | 100 | Partner-avoidance belief **`noLongerDetected`** while work pressure is “current” | **Surprising / painful** — “that used to be me” moment, undermined because **current** is the wrong work belief |
| Founder | 100+ | Retired runway/hiring versions with weakening events | **Interesting** |
| Burned-out | 100+ | Retired promotion-chase + phased boundary events | **Interesting** |
| Most @50 | — | Only `firstAppearance` on active belief | **Obvious** — no arc yet |

Lifecycle does not yet deliver consistent “death of an old story” at 50 reflections. Emotional peak requires evolution history + 100+ entries.

### 3. Did Change Feed increase perceived value?

**Yes — strongest new surface for “since last review.”**

Examples from raw JSON:

- **Founder @50:** Career theme `41 → 9` mentions; Avoidance `8 → 9`; 25 new reflections since simulated review.
- **Founder @200:** Beliefs strengthened: postpone hiring **47% → 71%**; runway belief **22% → 39%**; Career monthly series `15 → 44 → 9`.
- **Relationship @100:** Partner belief **weakened 66% → 28%**; Avoidance/Relationships trend `39 → 7 → 7`.
- **Burned-out / fitness L2+:** Belief weakened rows in most runs — reinforces “something shifted since I last opened Archive.”

**Weakness:** `contradictionsAppeared` / `resolved` usually **0** even when V1/Analyst eventually show pairs (founder @200). Users expect tension in “What Changed” — section under-delivers vs beliefs/themes.

### 4. “I didn’t know that” moments

| Moment | Persona | Evidence |
|--------|---------|----------|
| Theory confidence **25%** on cofounder avoidance despite 126 supporting mentions | Founder @200 | Counters + contradiction pressure surfaced honestly |
| Debate counter: boundary attempt vs “love this team” | Burned-out @200 | `firstCounterQuote` in analyst JSON |
| Debate counter: “Rest days… not failure” vs discipline | Fitness @100+ | User’s own words reframe streak belief |
| Partner belief **no longer detected** | Relationship @100 | Lifecycle retired row |
| Change Feed: partner belief **66% → 28%** since review | Relationship @100 | Simulated return visit |
| Hiring vs avoidance **competing** at 68–72% with different semantics | Founder @50–100 | Competing beliefs (not a trait row) |

**Missing “didn’t know” moments:** Seeded oppositions (love team vs dread Slack, lonely vs fine, rest vs self-punishment) **not** in Analyst contradictions at most sizes — user already “knows” their tension; archive fails to name it.

---

## Persona summaries (50 / 100 / 200)

### Founder

**Arc:** Fading runway-before-hiring; emerging cofounder avoidance; gut-vs-data tension.

| Size | Theory | Lifecycle | Change Feed | Deep Dive | Analyst |
|------|--------|-----------|-------------|-----------|---------|
| 50 | Interesting (70%, counters 0) | Obvious | Interesting — Career ↓ `41→9` | Obvious | Interesting — hiring vs avoidance competing |
| 100 | Interesting | Interesting — retired versions | Interesting — belief deltas | Obvious | Interesting — emerging series noisy |
| 200 | **Surprising** (25%, 24 ctr) | Interesting | Interesting — strengthened hiring/runway | Interesting | Interesting — debate counter on data vs instinct |

**Issues:** Primary also listed as **fading** @50; 0% trait rows; contradictions weak/truncated at 200; blind spot = “career” theme.

### Burned-out employee

**Arc:** Exhaustion dominant; boundaries emerging; love team vs dread Slack (seeded, not surfaced).

| Size | Theory | Lifecycle | Change Feed | Deep Dive | Analyst |
|------|--------|-----------|-------------|-----------|---------|
| 50 | Obvious (47%) | Interesting — events on exhaustion | Interesting | Interesting | **Surprising** — debate counter |
| 100 | Interesting | Interesting | **Surprising** — weakened beliefs | **Surprising** — then/now + counters | **Surprising** |
| 200 | Interesting | Interesting | **Surprising** | **Surprising** | **Surprising** |

**Best overall persona for V2 stack.** Change Feed + Theory + Debate align on exhaustion vs boundaries.

### Anxious overthinker

**Arc:** Replay + certainty-seeking; ambiguity vs closure (not in contradictions).

| Size | Theory | Lifecycle | Change Feed | Deep Dive | Analyst |
|------|--------|-----------|-------------|-----------|---------|
| 50 | Interesting | Obvious | Interesting | Obvious | Interesting |
| 100 | Obvious | Obvious | Surprising — weakened | Interesting | Interesting — debate counter |
| 200 | Obvious | Interesting | Surprising | Surprising | Interesting |

**Issues:** Generic blind spot “plans without wins”; trait “You express confidence”; no seeded contradiction.

### Relationship-focused

**Arc:** Partner avoidance vs work noise; lonely vs fine (seeded).

| Size | Theory | Lifecycle | Change Feed | Deep Dive | Analyst |
|------|--------|-----------|-------------|-----------|---------|
| 50 | Obvious | Obvious | Surprising — weakened partner belief | Obvious — **work** primary | Interesting — debate with **off-topic** work counter |
| 100 | Obvious (0%, wrong stmt) | **Surprising** — partner **noLongerDetected** | Surprising | Obvious — misaligned | Interesting |
| 200 | Obvious | Interesting | Surprising | Obvious — misaligned | Interesting |

**Critical failure:** V1/Theory/Deep Dive primary = **work delivery pressure** while Analyst primary @50 = partner avoidance. Lifecycle’s emotional win (retired partner belief) conflicts with headline — **destroys “historian” positioning**.

### Fitness-focused

**Arc:** Sleep-skips vs discipline; rest vs self-punishment (seeded).

| Size | Theory | Lifecycle | Change Feed | Deep Dive | Analyst |
|------|--------|-----------|-------------|-----------|---------|
| 50 | Interesting | Obvious | Interesting | Obvious | Interesting |
| 100 | Interesting | Obvious | Surprising | Interesting | **Surprising** — rest counter-quote |
| 200 | Interesting | Obvious | Surprising | Interesting | **Surprising** |

Strong debate/share moment; contradictions still empty in Analyst.

---

## Cross-cutting issues (still blocking surprise)

### Generic outputs

- Blind spots: **“You may keep returning to «theme».”** (all personas)
- Competing filler: **“Your archive working belief is forming from reflections”** (×9 cross-persona)
- Identity traits: **“You focus on career/health”**, **“You avoid conflict”**, **“You express confidence”** at 0% with full archive as “counter”
- Theory strengthen templates at high confidence (not user quotes)

### Weak confidence scores

- **Good:** Founder avoidance 25% @200; exhaustion 43–47% burned-out
- **Bad:** 0% beliefs still listed in Analyst Current/Competing (every scenario with catalog noise)
- **Bad:** Relationship work belief 0% evidence, 67 counters — mathematically “honest” but **nonsense primary**

### False / weak contradictions

- Founder @200: pairs truncate mid-sentence; keyword overlap without user-meaningful opposition
- Analyst `contradictionCount: 0` for burned-out, relationship, fitness despite fixture tensions

### Off-topic counter-evidence

- `hits == 0` → entire archive counted as counter (relationship debate: manager quote vs partner belief)
- `counterExceedsSupport` in metrics for **every** scenario

### Weak surprise generation

- Emerging/fading monthly series **duplicated** on same statement (founder)
- Dominant belief labeled **fading** while primary (founder @50)
- Change Feed contradictions channel empty
- Lifecycle “strengthening” on **wrong** current (relationship @100 work pressure)

---

## Deep Dive vs V2 alignment

| Persona | Theory/hero | Deep Dive | Aligned? |
|---------|-------------|-----------|----------|
| Founder | Cofounder avoidance | Same | Yes |
| Burned-out | Exhaustion | Same + counters @100+ | Yes |
| Anxious | Replay/certainty | Same | Yes |
| Relationship | Work pressure (V1) vs partner (Analyst @50) | Work | **No** |
| Fitness | Sleep/discipline | Same | Yes |

Deep Dive inherits primary selection — fixing ranking fixes Theory, Lifecycle current, Change Feed belief rows, and Deep Dive together.

---

## QA checklist (V2)

- [ ] Theory `statement` matches **semantic** dominant arc (not last work obs in relationship fixture)
- [ ] No 0%-confidence rows in Analyst Current/Competing
- [ ] Lifecycle `current` matches Theory statement
- [ ] Change Feed surfaces seeded contradictions when they newly appear after review
- [ ] Theory strengthen lines are quote-backed only
- [ ] Debate counters share theme/keywords with belief under review
- [ ] Dominant current belief not also in fading
- [ ] Blind spots cite quotes, not theme names
- [ ] Level 3 exercised at 200+ eligible (fixture extension)

---

## Decision: GPT-5 Archive Synthesis

| Criterion | Status |
|-----------|--------|
| Evidence-backed read path without new LLM | **Proven** for debate excerpts, Theory counters, Change Feed deltas |
| Surprising longitudinal insight | **Episodic** — 11/15 scenarios, persona-dependent |
| Trust before monetization | **Not ready** — wrong primary + off-topic counters + 0% rows |
| New model ROI vs ranking fixes | **Ranking fixes win** — synthesis would narrate the same wrong belief more fluently |

**Recommendation:** Ship **trust/ranking fixes** from [NEXT_HIGHEST_ROI_IMPROVEMENTS.md](./NEXT_HIGHEST_ROI_IMPROVEMENTS.md), re-run this harness, then reconsider GPT-5 for **optional** narrative polish on already-correct structures — not as a substitute for evidence matching.

---

## Raw artifacts

- `apps/voicememory_mobile/tool/output/archive_quality_raw.json` — includes `theory`, `lifecycle`, `changeFeed`, `metrics.*` V2 fields
- `apps/voicememory_mobile/tool/output/archive_v2_validation_summary.json` — per-scenario grades
