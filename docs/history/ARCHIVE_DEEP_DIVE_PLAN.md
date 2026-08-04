> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive Deep Dive V1 — plan

## Goal

When the archive surfaces a belief (and related contradictions / blind spots), let the user explore **why** through evidence and reflection — without CBT programs, coaching journeys, habit plans, or generic AI chat.

## Non-goals

- New AI / LLM infrastructure
- Therapy, coaching, or habit product surfaces
- Open-ended chat

## Reused engines (no duplication)

| Capability | Engine / module |
|------------|-----------------|
| Evidence gating (≥5 eligible transcripts) | `ArchiveEvidenceGuard` / `archiveHasMinimumEvidence` |
| Current belief + supporting entries | `DiscoverBeliefEngine` via `ArchiveV1Builder` |
| Contradictions | `DiscoverContradictionEngine`, `ArchiveThemeGapEngine` |
| Blind spots | `DiscoverBlindSpotEngine` |
| THEN / NOW versions | `BeliefEvolutionService` + `ArchiveV1Builder._buildThenNow` |
| Belief strength over time | `BeliefTimelineEngine` |
| Related themes / links | `CrossReferenceEngine` |
| Supporting excerpts UI | `ArchiveEvidencePanel` |
| Evolution blocks UI | `BeliefEvolutionTimelineWidget` |

## New module (`lib/features/archive_deep_dive/`)

| File | Role |
|------|------|
| `archive_deep_dive_gate.dart` | `canOpenDeepDive(ArchiveV1View)` |
| `archive_deep_dive_models.dart` | View models for all sections |
| `archive_deep_dive_engine.dart` | Composes V1 + engines into `ArchiveDeepDiveView` |
| `archive_deep_dive_inquiry_engine.dart` | Evidence-based inquiry question templates |
| `archive_deep_dive_reflection_service.dart` | Saves inquiry answers as local journal reflections |
| `archive_deep_dive_copy.dart` | User-facing strings |

## Route

- **Path:** `/archive-deep-dive`
- **Extra:** `ArchiveV1View` (same as evidence trail)
- **Redirect:** insufficient evidence → pop or empty state

## Screen sections (order)

1. **Current belief** — statement, confidence, disclaimer (“interpretation, not fact”)
2. **Why the archive thinks this** — count, summary, supporting recordings + excerpts
3. **Belief history** — first / strongest / latest appearances; THEN / NOW with evidence snapshots
4. **Evidence for / against** — two columns; against includes contradictions + low-overlap recordings
5. **Pattern explorer** — related themes, contradictions, blind spots (from `CrossReferenceEngine` + V1)
6. **Self-inquiry** — generated questions + text field; save → journal entry
7. **Belief timeline** — first mention, key recordings, evolution events, recent evidence

## Entry points (V1)

- **Belief hero CTA:** `Show me why` → `/archive-deep-dive`
- Evidence trail remains available from deep dive “Supporting excerpts” (no removal)

## Gating

Deep dive opens only when:

- `archiveHasMinimumEvidence(entries)`
- `ArchiveV1View.belief != null`
- At least one supporting recording on the belief card

## Tests

- `test/archive_deep_dive_engine_test.dart` — gate, why section, counter-evidence, inquiries
- `test/archive_deep_dive_gate_test.dart` — threshold edge cases

Run:

```bash
cd apps/voicememory_mobile
flutter test test/archive_deep_dive_gate_test.dart test/archive_deep_dive_engine_test.dart
```

## Analytics (optional V1)

- None required for V1; screen is local-only.

