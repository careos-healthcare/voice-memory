> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Next 3 Highest-ROI Archive Improvements

Derived from [ARCHIVE_PRODUCT_MARKET_FIT_AUDIT.md](./ARCHIVE_PRODUCT_MARKET_FIT_AUDIT.md) (full validation pass, 2026-05-25).

**Rules:** No new features · No redesigns · No GPT-5 migration · Ranking and evidence-matching fixes only.

**North star:** *ChatGPT helps you think. ArchiveMe shows what keeps repeating across your life.*

**Current PMF:** Change Feed is the strongest return hook; Debate is the strongest insight/share moment when on-topic; Blind Spots and 0% trait rows block willingness to pay for 3/5 personas.

---

## The three changes

### 1. Topical counter-evidence only

**What:** Stop treating every non-keyword-matching reflection as counter-evidence (`hits == 0` → full archive as counter). Require theme/keyword overlap or explicit `tensionOrContradiction` on the reflection.

| Impact | Score | Why |
|--------|-------|-----|
| **Retention** | ●●● | Correct confidence over time makes Change Feed and Lifecycle deltas believable on revisit. |
| **Trust** | ●●●●● | Fixes inverted scores (e.g. relationship work belief 0% / 67 counters), trait rows at 0%, and off-topic debate quotes. |
| **Willingness to pay** | ●●●●● | Users will not pay for conclusions that feel fabricated from unrelated recordings. |

**Unblocks:** Theory %, Analyst Current/Competing, Archive Debate, Deep Dive counters, Lifecycle status.

**Not in scope:** New models, new sections.

---

### 2. Primary belief / Theory statement selection

**What:** Rank the archive headline by evidence mass + recency + thematic dominance — not last `concreteObservation` alone.

| Impact | Score | Why |
|--------|-------|-----|
| **Retention** | ●●●●● | Wrong primary (relationship → work pressure) collapses reason to return; right primary unlocks Lifecycle + Deep Dive + Theory as one story. |
| **Trust** | ●●●●● | Single narrative aligned across Theory, Lifecycle `current`, Deep Dive, and Change Feed belief rows. |
| **Willingness to pay** | ●●●●● | Relationship persona moves from **Weak** to viable PMF; founder arc (hiring vs avoidance) surfaces at the right time. |

**Depends on:** #1 for stable confidence on the chosen statement.

**Not in scope:** Redesign of Archive UI or new synthesis layer.

---

### 3. Filter Analyst / Competing output (0% and trait rows)

**What:** Drop from Current and Competing: `confidencePercent == 0`, `evidenceCount < 3`, identity traits (“You focus on…”, “You avoid conflict”, “You express confidence”), and “forming from reflections” placeholders.

| Impact | Score | Why |
|--------|-------|-----|
| **Retention** | ●●● | Less noise on second visit; emerging/fading/competing read as a small set of real hypotheses. |
| **Trust** | ●●●●● | Removes the strongest “generic ChatGPT” signal in every persona run (15/15 scenarios listed 0% beliefs). |
| **Willingness to pay** | ●●●●● | Pay intent requires feeling the archive is a **historian**, not a theme tagger beside real observations. |

**Pairs with:** #1 (many 0% rows are counter-inflation artifacts).

**Not in scope:** New catalog entries or Analyst sections.

---

## Why only these three (and not four through twelve)

| Deferred item | Why it’s #4+ not top 3 |
|---------------|-------------------------|
| Pass seeded contradictions to Analyst + Change Feed | High shareability, but **empty contradictions are a symptom** of weak matching and wrong primary — fix #1–#3 first. |
| Debate on-topic excerpt scoping | Largely the same fix as #1, scoped to debate UI. |
| Emerging vs fading invariants | Hurts credibility but not as blocking as wrong primary + 0% rows. |
| Lifecycle sync to Theory | Follows automatically from #2. |
| Theory quote-only strengthen lines | Polish after trust. |
| Blind spots quote-backed or suppress | Weakest **feature**; suppressing is polish — #2–#3 remove the bigger trust leak. |
| Evidence tap-through | Improves share/pay proof after conclusions are correct. |

Full backlog: [NEXT_HIGHEST_ROI_IMPROVEMENTS.md](./NEXT_HIGHEST_ROI_IMPROVEMENTS.md).

---

## Suggested ship order

```text
1 → 3 → 2
```

Counter matcher first (correct scores), filter noise second (clean UI), primary selection third (aligned headline on clean data).

---

## Re-validation (before any paid positioning or GPT-5)

```bash
cd apps/voicememory_mobile
flutter test test/archive_quality_validation_test.dart
dart run tool/analyze_archive_v2_validation.dart
```

| Metric | Baseline (PMF audit) | Target |
|--------|----------------------|--------|
| Personas with pay verdict **Strong** @100+ | 1 (burned-out) | ≥ 3 |
| `zeroConfidenceListed` in metrics | 15/15 scenarios | 0/15 |
| Relationship Theory matches partner arc | No | Yes |
| Scenarios with ≥1 surprise moment | 11/15 | ≥ 13/15 |
| Blind Spots still only theme template | 5/5 personas | Suppressed or quote-backed |

---

## Expected outcome

After these three changes — still no new Archive surfaces — ArchiveMe should read as:

- **Return:** Change Feed shows drift you cannot see in one chat thread.
- **Trust:** Theory and Debate cite the same story with defensible counts.
- **Pay:** Burned-out, fitness, founder, and relationship personas approach the same bar burned-out hits today.

That is the minimum bar for asking “worth paying for?” again without GPT-5.

