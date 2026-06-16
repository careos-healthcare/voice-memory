# Archive Analyst V1 — plan

## Goal

A **periodic archive review** synthesized from accumulated evidence — not a chatbot, therapy, or coaching flow. The analyst reads like a **historian** of the user’s recordings, not a motivational coach.

## Non-goals

- New LLM / AI infrastructure
- Open-ended chat
- CBT, habit plans, or generic self-help copy

## Reused modules

| Module | Use in Analyst |
|--------|----------------|
| `ArchiveV1Builder` | Contradictions, blind spots, primary belief, eligible entries |
| `ArchiveDeepDiveEngine` | Debate excerpts (for/against) for primary belief |
| `DiscoverBeliefEngine` | Primary belief candidate |
| `BeliefEvolutionService` | Version history, emerging/fading signals |
| `IdentityEngine` | Trait lines as belief hypotheses + trends |
| `BeliefTimelineEngine` | Monthly strength per belief text |
| `DiscoverContradictionEngine` / V1 gaps | Contradiction section + confidence penalty |
| `DiscoverBlindSpotEngine` | Blind spot section |
| `archiveEligibleEvidenceEntries` | Gating and scoring input |

## New module (`lib/features/archive_analyst/`)

| File | Role |
|------|------|
| `archive_analyst_gate.dart` | 50 / 100 / 200 reflection thresholds |
| `archive_analyst_confidence_engine.dart` | 0–100 confidence from evidence signals |
| `archive_analyst_belief_catalog.dart` | Collect belief candidates (no AI) |
| `archive_analyst_models.dart` | Report types |
| `archive_analyst_engine.dart` | Compose full report |
| `archive_analyst_copy.dart` | Historian-tone strings |

## Route

- **`/archive-analyst`** — `ArchiveAnalystScreen` (loads journal + builds report)

Entry: Archive drawer → **Archive Analyst** (visible when level ≥ 1).

## Gating

| Eligible reflections | UI |
|---------------------|-----|
| &lt; 50 | “We need more evidence.” + count toward 50 |
| ≥ 50 | **Level 1** — Analyst Report |
| ≥ 100 | **Level 2** — deeper lists (more beliefs, debates) |
| ≥ 200 | **Level 3** — full depth |

Eligible = transcript ≥ 24 chars (`ArchiveEvidenceGuard`).

## Confidence algorithm (summary)

Implemented in `archive_analyst_confidence_engine.dart`.

| Input | Weight |
|-------|--------|
| Supporting mention count | Up to **40** pts (`min(40, count × 2)`) |
| Consistency (support / support+counter) | Up to **25** pts |
| Recency (share in latest 25% of timeline) | Up to **20** pts |
| Contradiction strength (max V1 score) | Up to **−25** pts |
| Counter-evidence count | Up to **−20** pts |

**Modifiers:** &lt;3 supporting mentions ×0.6; no recent mention ×0.75. Clamped 0–100.

Confidence **decreases** when evidence is weak, contradictory, or stale — see `archive_analyst_confidence_test.dart`.

**Inputs:** evidence count, consistency (for / for+counter), recency (share in latest quartile of timeline), contradiction strength, counter-evidence count.

**Decreases when:** few mentions, high counter ratio, stale last mention, strong contradictions.

**Output:** 0–100 integer, clamped.

## Report sections

1. Current Beliefs — ranked by confidence  
2. Emerging Beliefs — mention trend up  
3. Fading Beliefs — mention trend down  
4. Contradictions — from V1  
5. Blind Spots — from V1  
6. Competing Beliefs — alternatives with % (not single truth)  
7. Archive Debate — FOR / AGAINST per top belief(s)  
8. Evidence Summary — totals, date span, level label  

## Copy tone

- Evidence counts, dates, excerpts  
- “The archive weighed…”, “Possible explanations”  
- Avoid: “You should”, “Try to”, “Journey”, “Heal”
