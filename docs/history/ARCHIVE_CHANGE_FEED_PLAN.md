> Historical, non-authoritative. Superseded and retained for context only. Do not use for release decisions.

# Archive Change Feed V1 — plan

## Goal

**What Changed Since Last Review** — evidence-backed deltas, not static coaching copy.

## Review baseline

Reuse **`ArchiveStateSnapshot`** (`archiveStateSnapshot` prefs key), written when the user leaves the Archive screen (`ArchiveBeliefScreen.dispose` → `writeSnapshot`). Compare:

- **Then:** eligible reflections with `createdAt <= snapshot.timestamp`
- **Now:** full eligible archive

First visit (no snapshot): empty feed with honest copy.

## Tracked changes

| Category | Source |
|----------|--------|
| Beliefs strengthened | `ArchiveAnalystBeliefCatalog` + `ArchiveAnalystConfidenceEngine` — confidence now − then ≥ 8 |
| Beliefs weakened | Same — then − now ≥ 8 |
| Contradictions appeared | `DiscoverContradictionEngine` + `ArchiveThemeGapEngine` on now vs then |
| Contradictions resolved | Pairs in then, absent in now |
| Themes increasing | `ThemeTrackerService` canonical themes; mention series rising (last 3 months) + count up since review |
| Themes decreasing | Falling series + count down since review |

## Display

- Section title: **What Changed Since Last Review**
- Per row: label, **trend series**, evidence counts (beliefs/contradictions), mini bar chart (themes)
- Belief rows: confidence `before% → now%`, supporting + counter-evidence counts
- Contradiction rows: you say / vs / recording count + confidence score

### Examples (theme rows)

```
Work anxiety:
4 → 9 → 15 mentions

Confidence concerns:
11 → 7 → 3 mentions
```

`mentionsAtReview` / `mentionsNow` use the **last month bucket** in the at-review vs full-archive series (not lifetime totals), so a declining month trend can show `11 → 7 → 3` even when new reflections since review exist.

## Reproduce

```bash
cd apps/voicememory_mobile
flutter test test/archive_change_feed_engine_test.dart
```

## Module

`apps/voicememory_mobile/lib/features/archive_change_feed/`

| File | Role |
|------|------|
| `archive_change_feed_models.dart` | Feed + row types |
| `archive_change_feed_copy.dart` | Strings |
| `archive_change_feed_engine.dart` | Delta engine |
| `lib/widgets/archive_v1/archive_change_feed_section.dart` | UI |

## Integration

- `ArchiveV1Builder.build(baseline: …)` → `ArchiveChangeFeedView`
- `ArchiveV1Body` — render after theory hero

## Tests

`test/archive_change_feed_engine_test.dart`

