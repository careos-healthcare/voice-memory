> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Belief Lifecycle V1 — plan

## Goal

Track how beliefs appear, strengthen, weaken, and end in the archive using **existing belief history only** — no new AI systems.

## Phases tracked (internal)

| Phase | Detection |
|-------|-----------|
| **First appearance** | Earliest eligible reflection with keyword overlap to the statement |
| **Strengthening** | `BeliefTimelineEngine` trend `strengthening`, or evolution confidence step-up (≥ 8) |
| **Weakening** | Timeline trend `weakening`, or evolution confidence step-down (≤ −8) |
| **Death** | Not the active theory and no mentions in the recent evidence window (retired evolution versions) |

## Display (user-facing)

### Active theory

| Field | Source |
|-------|--------|
| **First Seen** | Earliest mention date (`formatUserFacingDate`) |
| **Last Seen** | Latest mention date |
| **Status** | Emerging · Stable · Weakening · Dormant · No Longer Detected |

### Retired belief — no longer detected

```
Belief No Longer Detected

"I'm not ready"

Last detected:
14 March 2026
```

(No status line on this card — status is implied by the header.)

## Status rules

| Status | Rule (summary) |
|--------|----------------|
| **Emerging** | Active + timeline strengthening, or first seen in recent quarter with thin evidence |
| **Stable** | Active + recent mentions + trend stable |
| **Weakening** | Active + timeline weakening |
| **Dormant** | Active + past mentions but none in latest 25% of timeline (`split.stale`) |
| **No Longer Detected** | Not active + no recent mentions (prior evolution versions) |

## Data sources (reuse only)

| Source | Use |
|--------|-----|
| `ArchiveAnalystConfidenceEngine.splitEntries` | Mentions, stale flag, first/last supporting dates |
| `BeliefTimelineEngine` | Monthly strength + trend |
| `BeliefEvolutionService` / `BeliefEvolutionState.versions` | Prior belief texts for retired cards |
| `formatUserFacingDate` | First Seen / Last Seen / Last detected |

## Module

`apps/voicememory_mobile/lib/features/belief_lifecycle/`

| File | Role |
|------|------|
| `belief_lifecycle_models.dart` | Status, phases, events, `BeliefLifecycleView` |
| `belief_lifecycle_copy.dart` | User-facing strings |
| `belief_lifecycle_engine.dart` | Compose lifecycle from entries + evolution |

## UI

| File | Role |
|------|------|
| `lib/widgets/archive_v1/belief_lifecycle_section.dart` | Current theory + retired beliefs |

## Integration

- `ArchiveV1Builder.build` → `BeliefLifecycleView` on `ArchiveV1View`
- `ArchiveV1Body` — section after Change Feed, before Then/Now

## Tests

`test/belief_lifecycle_engine_test.dart`

## Reproduce

```bash
cd apps/voicememory_mobile
flutter test test/belief_lifecycle_engine_test.dart
```

