# Widget & Shortcut Preparation

ArchiveMe keeps one useful check ready. This document describes the snapshot
contract and native widget integration for home-screen Today\u2019s Check.

## Snapshot contract

Persisted under prefs key `current_objective_widget_snapshot` by
`CurrentObjectiveSnapshotStore`.

| Field | Type | Notes |
|-------|------|-------|
| `title` | string | Short headline, max 80 chars when built |
| `body` | string | One-line guidance, max 120 chars when built |
| `checkQuestion` | string? | Today/tomorrow check only; max 100 chars |
| `primaryActionLabel` | string | CTA label, max 40 chars |
| `route` | string | Deep link route, defaults to `/record` |
| `type` | string | `CurrentObjectiveType` id (e.g. `answerTodayCheck`) |
| `updatedAt` | ISO-8601 UTC | When the snapshot was written |

Built by `buildWidgetSnapshot(CurrentObjective)` and exported to native code
via `buildWidgetPayload()` in `current_objective_widget_exporter.dart`.

## Privacy rules

- **Do not expose full reflection text** in widget snapshots.
- Only the consumer-visible **check question** may appear (if the user chose a
  check).
- No pattern titles, transcript excerpts, mood labels, or long summaries.
- Bodies are capped to short, home-screen-safe lengths.
- Widgets show **title, body, optional check question, and one action only**.

## Android widget (implemented)

Minimal home-screen App Widget:

- Provider: `TodayCheckWidgetProvider`
- Layout: `res/layout/today_check_widget.xml`
- Storage: `ObjectiveWidgetStorage` (`archive_me_today_check_widget` prefs)
- Method channel: `archive_me/current_objective_widget`
  - `updateCurrentObjectiveWidget`
  - `clearCurrentObjectiveWidget`
  - `isCurrentObjectiveWidgetAvailable`
  - `consumePendingWidgetRoute`

When the objective card saves a snapshot, `CurrentObjectiveWidgetRefreshService`
pushes the payload to Android and requests a widget update.

Widget tap opens `MainActivity` with a pending route (usually `/record`).
Flutter reads the route on launch via `consumePendingWidgetRoute`.

## iOS WidgetKit

Swift source and entitlements live in `ios/TodayCheckWidget/` and
`ios/Runner/ObjectiveWidgetStorage.swift`. AppDelegate implements the same
method channel and writes to App Group **`group.com.voicememory.mobile`**.

The Widget extension **target must be added once in Xcode** — see
`docs/IOS_WIDGETKIT_SETUP.md`.

Widget tap uses `archiveme://record` (or payload route). Flutter reads the
pending route via `consumePendingWidgetRoute`.

See `docs/TODAYS_CHECK_WIDGET_QA.md` for manual QA steps.

## Shortcut actions

Registered in `ObjectiveShortcutRegistry` (Dart-only today):

| id | label | route |
|----|-------|-------|
| `openRecord` | Open Record | `/record` |
| `answerCheck` | Answer check | `/record` |
| `recordMoment` | Record moment | `/record` |
| `openPatterns` | Open Patterns | `/patterns` |

Native Siri Shortcuts / Android App Shortcuts will map to these ids later.

## Manual QA

See `docs/TODAYS_CHECK_WIDGET_QA.md`.

## Related files

- `lib/features/objective/current_objective_widget_snapshot.dart`
- `lib/features/objective/current_objective_snapshot_builder.dart`
- `lib/features/objective/current_objective_snapshot_store.dart`
- `lib/features/objective/current_objective_widget_exporter.dart`
- `lib/features/objective/current_objective_widget_bridge.dart`
- `lib/features/objective/current_objective_widget_refresh_service.dart`
- `lib/features/objective/objective_widget_pending_route_store.dart`
- `lib/widgets/objective/current_objective_card.dart`
- `android/.../TodayCheckWidgetProvider.kt`
