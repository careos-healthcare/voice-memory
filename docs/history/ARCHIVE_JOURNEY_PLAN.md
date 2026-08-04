> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive Journey Plan (Growth Loop V1)

## Goal

Deliver the **first wow moment** on Day 1, a recurring pattern on Day 3, and the first visible change on Day 7 — without new AI systems.

## Route

- Mobile: `/archive-journey` (`ArchiveJourneyScreen`)
- Entry points: Archive home journey banner, maturity card “Journey” link

## States

| Step | Unlock | Reward source |
|------|--------|----------------|
| Day 1 | ≥1 eligible recording | Latest reflection: `concreteObservation`, `tensionOrContradiction`, or `repeatedSignal` |
| Day 3 | ≥3 calendar days **or** ≥3 recordings | Top `recurringThemes` count ≥3, or “similar concerns N times” |
| Day 7 | ≥7 days **or** ≥7 recordings | `ArchiveV1` change feed (`themesDecreasing`, `beliefsWeakened`), surprises, or week-span fallback |

## Engines (existing only)

- `archiveEligibleEvidenceEntries` — evidence gate
- `ArchiveV1Builder` — change feed + surprises for Day 7
- Reflection fields on `JournalEntry` — Day 1 / Day 3

## UI

- **Archive home:** `ArchiveJourneyBanner` (progress bar + next reward teaser)
- **Journey screen:** three step cards with lock/unlock/check states
- Progress: `completedCount / 3` shown prominently

## Copy principles

- Trust language (“The archive noticed…”)
- No streaks, points, or leaderboards
- Pending copy when reward not yet computable

## Persistence

- `ArchiveJourneyStore` (prefs) — optional manual acknowledgement; auto-complete when reward is non-empty

## Out of scope

- Push notifications for journey steps (future)
- Server-side journey (local-first archive)

