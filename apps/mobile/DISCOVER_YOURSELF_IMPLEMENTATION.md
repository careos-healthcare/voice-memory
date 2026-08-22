# Discover Yourself — implementation

## Overview

Discover Yourself turns ArchiveMe from a static archive into a **local, self-discovery dashboard**. All insights are computed on-device from journal entries — no network calls. The feature complements the existing Archive tab; nothing was removed from Archive belief surfaces.

## Architecture

```
DiscoverYourselfScreen
        │
        ▼
DiscoverYourselfEngine (orchestrator + cache)
        │
        ├── DiscoverBeliefEngine
        ├── BeliefShiftEngine (belief changes)
        ├── DiscoverThemeEngine
        ├── DiscoverContradictionEngine → ContradictionDetectionService
        ├── DiscoverBlindSpotEngine → BlindSpotLocalEngine
        ├── DiscoverChapterEngine → LifeChapterEngine
        ├── DiscoverGrowthTimelineEngine
        └── Ask-archive heuristics (prompt → DiscoverArchiveAnswer)

DiscoverYourselfCache — fingerprint memoization (entry count + last id + timestamp)
```

## Routes

| Route | Purpose |
|-------|---------|
| `/discover-yourself` | Primary shell tab — dashboard |
| `/discover` | Redirect → `/discover-yourself` (legacy deep links) |
| `/discover-changes` | Previous “What Changed” feed (`DiscoverScreen`) |
| `/discover-yourself/chapter/:id` | Chapter detail with cited entries |

## Navigation

Bottom nav order: **Record | Archive | Discover | Timeline | Search | Account**

- Tab label: **Discover**
- Icon: `Icons.psychology`

## Insight generation logic

### Modes (entry count)

| Count | Mode | UX |
|-------|------|-----|
| 0 | `empty` | Single empty-state banner |
| 1–4 | `early` | “Keep recording…” banner |
| 5–20 | `growing` | Early sections (belief, themes, momentum, growth, ask) |
| 21+ | `full` | All sections including contradictions, blind spots, chapters |

Eligible reflections for evidence use `archiveEligibleEvidenceEntries` (transcript length ≥ 24).

### Engines (`lib/features/discover/`)

| File | Role |
|------|------|
| `discover_models.dart` | Snapshot + section DTOs |
| `discover_engine.dart` | Orchestration, header stats, momentum/streaks, ask-archive Q&A |
| `discover_cache.dart` | In-memory memoization |
| `belief_engine.dart` | Current belief card + confidence % |
| `theme_engine.dart` | Recurring themes + trend arrows + evidence ids |
| `contradiction_engine.dart` | Opposing statements via contradiction service |
| `blind_spot_engine.dart` | Blind spot cards (local + heuristics) |
| `chapter_engine.dart` | Life chapter summaries |
| `growth_timeline_engine.dart` | Month-by-month growth labels |
| `discover_analytics.dart` | Debug analytics events |

Belief **changes** reuse `BeliefShiftEngine` (top 5). Contradictions and blind spots reuse existing detection stacks.

### Ask Your Archive

Five prompt chips call `DiscoverYourselfEngine.answerArchiveQuestion`. Answers are heuristic summaries with `citedEntryIds` linking to `/entry/:id`.

### Performance

- First open: builds snapshot once, stores in `DiscoverYourselfCache`.
- Reopen with same fingerprint: returns cached snapshot (target &lt;100ms).
- Pull-to-refresh invalidates cache.

## Analytics (debug)

Events: `discover_opened`, `belief_expanded`, `theme_expanded`, `contradiction_viewed`, `blind_spot_viewed`, `chapter_opened`, `archive_question_asked` — logged via `debugPrint` in debug builds.

## Accessibility

- `Semantics` on header and stat chips
- Section headers marked as headers
- 48dp minimum tap targets on primary CTAs
- Tooltips on section titles where helpful

## Tests

- `test/discover_engine_test.dart` — modes, cache, ask-archive citations

## Future AI enhancements

- Replace heuristic ask-archive answers with on-device or privacy-preserving LLM summarization
- Embeddings for theme clustering and blind-spot detection
- User-labeled belief confirmations to train confidence
- Sync optional cloud narrative without blocking offline Discover
- Richer contradiction explanations with neutral framing
- Export “Discover report” PDF from snapshot
