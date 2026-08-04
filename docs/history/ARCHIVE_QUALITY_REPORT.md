> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive Quality Report

**Date:** 2026-05-25  
**Scope:** Archive V1, Archive Deep Dive, Archive Analyst (no new features)  
**Method:** 5 synthetic personas × 3 archive sizes (50 / 100 / 200 reflections), engines run on-device via `ArchiveV1Builder`, `ArchiveDeepDiveEngine`, `ArchiveAnalystEngine`.

## How to reproduce

```bash
cd apps/voicememory_mobile
flutter test test/archive_quality_validation_test.dart
dart run tool/summarize_archive_quality.dart
```

- Persona fixtures: `test/support/archive_quality_personas.dart`
- Raw JSON: `apps/voicememory_mobile/tool/output/archive_quality_raw.json`

**Note:** Some personas generate fewer than 200 physical entries in the fixture (e.g. Founder full corpus ≈151 eligible). “200 reflections” in those cases means “request 200, use all available.” Level 3 (200+ eligible) was not reached for any persona in this run.

---

## Executive summary

| Question | Verdict |
|----------|---------|
| **Would a user pay to see this?** | **Conditional no** at Level 1; **weak yes** at Level 2 for 2/5 personas (burned-out, fitness) when debate excerpts are grounded. Not pay-ready for relationship-focused or founder until contradictions and competing beliefs stop surfacing theme labels. |
| **Would a user share this?** | **Rarely today.** Shareable moments exist only when Archive Debate shows a specific counter-quote that reframes the primary belief (fitness rest vs discipline; burned-out love team vs dread Slack at 200). Generic blind-spot headlines are not shareable. |
| **“Oh wow” moments** | Competing beliefs that disagree in *meaning* (postpone hiring vs direct cofounder conversation); debate counter-lines that cite the user’s own words; fading runway belief at founder 200. |
| **Generic AI feel** | Identity traits (“You focus on career”), blind-spot theme loops (“You may keep returning to career”), secondary blind-spot templates (plans without wins), and 0%-confidence competing rows with counter = entire archive. |

**Overall:** The stack is strongest when beliefs are **verbatim user observations** with keyword-linked evidence. It feels like generic AI when the catalog injects **identity traits** and **keyword-absent entries** into counter-evidence and competing explanations.

---

## Grading key

| Grade | Meaning |
|-------|---------|
| **Obvious** | Restates the latest reflection or a dominant keyword users already know. |
| **Interesting** | Connects two evidence clusters the user might not have named (e.g. competing hiring vs avoidance). |
| **Surprising** | Non-trivial tension with dated counter-evidence or a contradiction the user did not state as a belief. |

---

## 1. Founder

**Synthetic arc:** Fading “runway before hiring”; emerging cofounder conflict avoidance; gut-vs-data contradiction; counter direct conversations; current “postpone hiring while team overloaded.”

### 50 reflections (Level 1, 50 eligible)

| Section | Output (abridged) | Grade | Issues |
|---------|-------------------|-------|--------|
| V1 belief | Avoid difficult cofounder conversations (66%) | Interesting | Matches recent obs, not “postpone hiring” arc |
| Current beliefs | Avoid cofounder 70%; Postpone hiring 68%; **You focus on career 0%** | Mixed | Two good rows; trait rows are noise |
| Emerging | **Empty** | — | Emerging arc not detected |
| Fading | Both top beliefs “declining 41→9” | **Wrong** | Dominant beliefs labeled fading (trend logic bug) |
| Contradictions | None | — | Missed gut vs data |
| Blind spots | “You may keep returning to career” | Obvious | Theme label, not historian insight |
| Competing | Avoid vs postpone (meaningful) + 0% career | Interesting / Obvious | Good pair polluted by trait |
| Archive Debate | Avoid cofounder: 50 for / **0 against** | Obvious | No challengeable conclusion |

### 100 reflections (Level 2)

| Section | Grade | Notes |
|---------|-------|-------|
| Current | Interesting | Postpone hiring ranks above avoidance; direct conversation appears |
| Emerging | Interesting | Monthly series surfaces growth (noisy numbers) |
| Contradictions | — | Still empty |
| Debate | Obvious | Still zero counter for top beliefs |

### 200 reflections (151 eligible, Level 2)

| Section | Grade | Notes |
|---------|-------|-------|
| Current | **Surprising** (partial) | Confidence drops on avoidance (25%) with real counters; runway fades to 17% |
| Contradictions | Obvious | Pairs often share keywords but not user-meaningful opposition (gut vs avoidance) |
| Debate | **Interesting** | Counter: “cannot ship without more data” vs hiring belief |
| Competing | Interesting | Hiring vs direct conversation vs runway — plausible alternatives |

---

## 2. Burned-out employee

**Arc:** Fading promotion chase; emerging boundaries; exhaustion dominant; love team vs dread Slack; helping others.

### 50 (Level 1)

| Section | Grade | Issues |
|---------|-------|--------|
| V1 | Exhaustion (66%) | Obvious | Correct primary |
| Current | Exhaustion 47%; boundaries 0% with 8 ev / 42 ctr | Weak confidence | Counter bucket inflates |
| Emerging | Boundaries ↑; helping others ↑ | Interesting | |
| Fading | Exhaustion “declining” while dominant | Wrong | |
| Blind spots | “career” theme | Obvious | |
| Debate | 40 for / 4 against | Interesting | Boundary quote as counter |

### 100 (Level 2)

| Section | Grade |
|---------|-------|
| Current | Interesting — exhaustion 43%, boundaries 24%, promotion 2% |
| Emerging | Interesting — exhaustion trend labeled rising (label vs semantics debatable) |
| Debate | Interesting — boundary vs exhaustion tension |

### 200 (114 eligible)

| Section | Grade |
|---------|-------|
| Competing | Interesting — exhaustion vs boundaries vs promotion vs helping |
| Debate | **Surprising** — boundaries counter: “love this team”; exhaustion counter: boundary attempt |
| Contradictions | — | Slack dread vs love team **not** in Analyst contradictions (V1 gap) |

---

## 3. Anxious overthinker

**Arc:** Fading spontaneous action; emerging certainty-seeking; replay dominant; ambiguity→closure contradiction.

### 50 / 100 / 200

| Section | Grade | Issues |
|---------|-------|--------|
| V1 / Current | Obvious → Interesting | Replay + certainty cluster is on-theme |
| Emerging | Interesting | Certainty trend visible at 100+ |
| Fading | — | “Used to act without certainty” only at 200 (23%) — late |
| Blind spots | Obvious | “confidence” theme + **generic** “plans without wins” (not in user data) |
| Contradictions | — | Missed ambiguity vs replay arc |
| Debate (100+) | **Interesting** | Counter: sent email without over-editing |
| Competing | Obvious | “You express confidence” at 0% — generic trait |

---

## 4. Relationship-focused

**Arc:** Work noise vs relationship importance; emerging partner-need avoidance; lonely vs “fine” tension.

### 50

| Section | Grade | Issues |
|---------|-------|--------|
| V1 | **Work delivery pressure** | Wrong | Latest obs in window is work-heavy, not relationship |
| Current | Avoid partner needs 21%; work 0% | Weak | Primary relationship insight buried |
| Debate | — | Low signal |

### 100 / 200

| Section | Grade |
|---------|-------|
| Current | Interesting at 200 | Avoid partner needs 40% with 102 evidence |
| Emerging | Interesting | Partner avoidance series 3→39 spike |
| Fading | Interesting | Work pressure “1→1…” rare (correct arc) |
| V1 primary | Still work pressure at 200 | **Bug/behavior** — last-observation belief ignores user’s stated “relationships matter most” |
| Debate | Obvious | Counters are **work transcripts**, not relationship counter-evidence |
| Contradictions | — | Theme gap / lonely vs fine not surfaced |

---

## 5. Fitness-focused

**Arc:** Fading strict discipline; emerging sleep-skips; rest vs self-punishment tension.

### 50 / 100 / 200

| Section | Grade | Issues |
|---------|-------|--------|
| V1 / Current | Obvious → Interesting | Sleep vs consistency belief is clear and stable |
| Emerging | Interesting | Skip-training trend rises |
| Competing | Interesting | Skip vs discipline vs streak |
| Debate | **Surprising** at 100+ | Counter: “Rest days… not failure” vs discipline |
| Blind spots | Obvious | “health” theme loop |
| Contradictions | — | Rest vs beat-yourself-up not in Analyst list |

---

## Cross-cutting findings

### Generic conclusions

- Blind spot primary: **“You may keep returning to «theme».”** (all personas)
- Secondary blind spot: **“future plans but rarely celebrate wins”** (anxious — not evidenced in fixtures)
- Competing filler: **“Your archive working belief is forming from reflections”** (×9 across runs)
- Identity traits: **“You focus on career/health/relationships”**, **“You avoid conflict”**, **“You express confidence”** at 0% support

### Repeated conclusions

- Same observation text appears as current, emerging, and competing (founder avoidance ×3 across personas in duplicate tracker)
- Emerging and fading both attach to the **same** belief when monthly buckets fluctuate (founder @50)

### Unsupported conclusions

- 0% confidence beliefs with `evidenceCount: 0` and `counterEvidenceCount: 50–146` (keyword mismatch → all other entries counted as counter)
- Founder contradictions pairing unrelated statements that share “difficult” or product language

### Weak confidence scoring

- High confidence (66–71%) with thin counter at 50 reflections; drops appropriately at 200 when counters appear — **good**
- **Bad:** 0% rows still listed in Current/Competing (should be filtered)
- **Bad:** Boundaries belief at 50 shows 0% despite 8 supporting mentions (counter dominates via unrelated entries)

### Missing evidence links

- Competing beliefs: no entry IDs or tap-through
- Emerging/fading: series numbers without month labels in Analyst UI copy (trend label only)
- Debates: strong when Deep Dive path aligns with V1 primary; otherwise excerpts OK but counters often **off-topic** (relationship persona)
- Level 1: **max 1 debate** hides best tension for multi-belief users

---

## Deep Dive vs Analyst alignment

| Persona | Deep Dive available | Alignment |
|---------|---------------------|-----------|
| Founder | Yes | Matches V1 primary; counter excerpts weak until 200 |
| Burned-out | Yes | Good counter at 200 |
| Anxious | Yes | Strong counter excerpts |
| Relationship | Yes | **Misaligned** — deep dive explains work belief, not partner avoidance |
| Fitness | Yes | Strong rest-vs-discipline counter |

---

## Gating check

| Size | Analyst | Expected |
|------|---------|----------|
| 50 | Level 1 | OK |
| 100 | Level 2 | OK |
| 200 | Level 2 (eligible &lt;200) | Level 3 not exercised in this run |

---

## QA checklist (insight quality)

- [ ] No 0%-confidence rows in Current or Competing
- [ ] Primary V1 belief matches user’s dominant *semantic* theme (not last obs when work noise &gt; relationship signal)
- [ ] Emerging and fading are mutually consistent with current rank (dominant belief not “fading”)
- [ ] Contradictions include seeded oppositions (team love/dread, rest/discipline, lonely/fine)
- [ ] Blind spots cite user quotes, not theme names
- [ ] Debate counter-excerpts are on-theme for the belief under review
- [ ] No “forming from reflections” in paid-tier reports
- [ ] Level 3 report generates at 200+ eligible reflections

---

## Section scorecard (aggregate)

| Section | Typical grade | Trust impact |
|---------|---------------|--------------|
| Current beliefs | Interesting (when verbatim obs) | High |
| Emerging | Interesting at 100+ | Medium |
| Fading | Mixed (logic errors at 50) | Medium |
| Contradictions | Weak / absent | High when missing |
| Blind spots | Obvious | Low |
| Competing | Interesting when obs-based; Obvious when traits | High |
| Archive Debate | Interesting–Surprising when counters on-topic | **Highest** |

---

## Raw artifacts

- `apps/voicememory_mobile/tool/output/archive_quality_raw.json` — full structured outputs + automated metrics (`genericPhraseHits`, `counterExceedsSupport`, `debatesMissingExcerpts`)

