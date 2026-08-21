# Archive Discovery Share Cards V1

Shareable archive moments as branded PNG cards with system share sheet export.

## Share card types

| Type | `card_type` (analytics) | Source |
|------|-------------------------|--------|
| Belief change | `belief_change` | `thenNow` evolution or `changeFeed.beliefsWeakened` |
| Pattern discovery | `pattern_discovery` | Recurring theme ≥3 mentions |
| Milestone | `milestone` | 50 / 100 / 200 eligible recordings |
| Contradiction | `contradiction` | `ArchiveV1.contradictions` |
| Change detected | `change_detected` | Change feed theme shift, new reflections, or surprise observation |

Up to **5 cards** per load via `ArchiveDiscoveryShareEngine`.

## Card format

```
My archive noticed:

"<quote>"

ArchiveMe
```

- No full transcripts — clipped quotes only.
- Footer brand: `ArchiveMe`.

## UI & export

| Component | Path |
|-----------|------|
| Model | `lib/features/archive_discovery_share/archive_discovery_share_card_model.dart` |
| Engine | `lib/features/archive_discovery_share/archive_discovery_share_engine.dart` |
| Widget | `lib/widgets/archive_discovery_share/archive_discovery_share_card.dart` |
| Screen | `/archive-share` → `ArchiveShareDiscoveriesScreen` |

**Export**

- **Share** — `RepaintBoundary` → PNG → `Share.shareXFiles` (share sheet + optional text).
- **PNG** — same render path, share sheet with image only.

**Analytics**

- Event: `discovery_shared`
- Params: `card_type`, `card_id`, `export_method` (`share_sheet` | `png`)

## Screenshots

```bash
cd apps/mobile
# Device/simulator with archive data + share discoveries
./tool/run_ui_screenshot_audit.sh
# Or navigate: Archive → Share a discovery → /archive-share
```

Suggested captures:

- `archive_share_discovery_card.png` — card preview with type label
- `archive_share_share_sheet.png` — system sheet after Share (manual)

## Tests

```bash
cd apps/mobile
flutter test test/archive_discovery_share_test.dart test/archive_growth_test.dart
```

Coverage: card types, V1 copy format, engine outputs (contradiction, milestone, pattern, change detected), widget layout keys.
