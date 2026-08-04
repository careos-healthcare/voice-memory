> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive V1 — Technical Plan

**Date:** 2026-06-03  
**App:** `apps/voicememory_mobile`  
**Goal:** Make Archive the product moat — belief, evolution, evidence, contradictions, blind spots — without a new AI stack.

---

## 1. Five questions the Archive must answer

| # | Question | V1 surface |
|---|----------|------------|
| 1 | What does the archive currently believe? | **Belief Hero Card** |
| 2 | How has that belief changed? | **Then → Now** (belief evolution) |
| 3 | What evidence supports it? | **Evidence Trail** screen |
| 4 | What contradictions exist? | **Contradictions** section |
| 5 | What blind spots exist? | **Blind Spots** section |

---

## 2. Current capabilities (reuse as-is)

| Capability | Location | Notes |
|------------|----------|-------|
| Eligible reflections / evidence guard | `archive_evidence_guard.dart` | Min 5 reflections, ≥24 char transcripts |
| Working belief text | `archiveBeliefFromReflections`, `DiscoverBeliefEngine` | Observation-first from reflections |
| Confidence display | `archive_confidence_display.dart` | Health + evidence count → % |
| Belief version history | `BeliefEvolutionService` + `BeliefEvolutionStore` | Local JSON in `mobile_prefs.json` |
| Statement-pair contradictions | `ContradictionDetectionService` | Opposing statements, confidence 52–100 |
| Discover contradiction cards | `DiscoverContradictionEngine` | Wraps detection, top 5 |
| Blind spots | `DiscoverBlindSpotEngine` + `BlindSpotLocalEngine` | Keyword/theme frequency heuristics |
| Evidence excerpts | `ArchiveEvidencePanel`, `BeliefEvolutionService.buildTimeline` | Real entry IDs + quotes |
| Archive state object | `buildArchiveStateObjectV3` | Belief, health, watch, change summary |
| Empty / insufficient UX | `EmptyArchivePanel`, `EmptyArchiveCopy` | Already shipped |
| Entry detail navigation | `/entry/:id` | Tap evidence → recording |

**Not used in V1 (demoted on Archive home):** Living Archive quick view hero, surprise engine, milestone overload, duplicate belief banners.

---

## 3. Gaps → V1 additions (minimal)

| Gap | V1 addition | Effort |
|-----|-------------|--------|
| Single hero with spec copy + tap-through | `ArchiveBeliefHeroCard` | S |
| Then/Now layout vs timeline blocks | `ArchiveBeliefEvolutionThenNow` | S |
| Theme-frequency contradictions (“say X, rarely mention”) | `ArchiveThemeGapEngine` | M |
| Unified Archive load | `ArchiveV1Builder` | S |
| Dedicated Evidence Trail screen | `ArchiveEvidenceTrailScreen` + route | M |
| Archive screen priority stack | Refactor `archive_belief_screen.dart` | M |

**Total estimate:** ~2–3 dev days for implementation + QA (no backend).

---

## 4. Architecture (V1)

```
ArchiveBeliefScreen
  └─ ArchiveV1Body (when hasMinimumEvidence)
       ├─ ArchiveBeliefHeroCard → /archive-evidence-trail
       ├─ ArchiveBeliefEvolutionThenNow
       ├─ ArchiveV1ContradictionsSection
       └─ ArchiveV1BlindSpotsSection

ArchiveV1Builder.build(entries, state, baseline)
  ├─ DiscoverBeliefEngine
  ├─ BeliefEvolutionService.refreshFromEntries + buildTimeline
  ├─ DiscoverContradictionEngine
  ├─ ArchiveThemeGapEngine (new, evidence-only)
  └─ DiscoverBlindSpotEngine
```

No new persistence schema. Belief evolution store unchanged.

---

## 5. Rules (launch safety)

- **No belief hero** unless `ArchiveEvidenceGuard.hasMinimumEvidence`.
- **No contradictions** with `confidenceScore < 60`.
- **No blind spots** with `confidence < 60`.
- **No fabricated** journal rows — all IDs must resolve in `entries`.
- Theme-gap contradictions require ≥5 eligible reflections and explicit transcript signals.

---

## 6. Launch risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Belief text = single observation line, not LLM belief | Medium | Label as archive conclusion; Evidence Trail shows excerpts |
| Thin evolution (one version) | Low | Then/Now shows “still forming” copy |
| Contradiction false positives | Medium | Confidence floor + cap at 5 items |
| Archive still shows ArchiveMe branding | Low | Rebrand separate; V1 copy uses “archive” |
| Quick view removed → less “alive” feel | Low | V1 is intentional moat focus |
| Updates synthetic notification (unchanged) | Medium | Out of V1 scope |

---

## 7. Out of scope (V1)

- New cloud belief API
- Hive/SQLite migration
- Replacing `ContradictionDetectionService` algorithm
- Web archive parity
- RevenueCat / auth changes

---

## 8. Deliverables checklist

- [x] `ARCHIVE_V1_PLAN.md` (this file)
- [x] `lib/features/archive_v1/*`
- [x] `lib/widgets/archive_v1/*`
- [x] `lib/screens/archive_evidence_trail_screen.dart`
- [x] `archive_belief_screen.dart` integration
- [x] `ARCHIVE_V1_TEST_PLAN.md`
- [x] Unit tests for `ArchiveV1Builder` + `ArchiveThemeGapEngine`

---

*End of plan.*

