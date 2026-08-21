# Widget release risk gate v1

Ensure the Today\u2019s Check widget/native extension cannot block TestFlight release. **Audit only** — no new widget features, sizes, or analytics.

## Decisions

| Decision | Meaning |
| --- | --- |
| `widgetSafe` | Widget can ship with TestFlight |
| `widgetNeedsManualXcodeCheck` | Run manual widget QA before enabling |
| `widgetDisableForRelease` | Defer/disable widget extension; main app can still ship |
| `widgetBlocksRelease` | Embedded extension breaks signing, TestFlight install, or launch |

## Checks (8)

1. Extension target present (iOS WidgetKit target in Xcode project)
2. App Group configured (`group.com.voicememory.mobile`)
3. Widget opens correct route (defaults to `/record`)
4. No private transcript shown (privacy policy in widget prep docs)
5. TestFlight install works
6. Signing passes
7. No crash on launch
8. No stale/broken default state

## Key rule

Missing extension target or App Group misconfiguration → **`widgetDisableForRelease`**, not `widgetBlocksRelease`. TestFlight can proceed without the widget.

Embedded extension + signing/TestFlight/launch failure → **`widgetBlocksRelease`**. Disable extension before archive.

## Repo signal bridge

`WidgetReleaseRiskGate.fromRepoSignals()` reads static repo files (pbxproj, entitlements, exporter, docs) without changing widget behavior.

## Code modules

- Engine: `lib/features/widget_release_risk/widget_release_risk_gate.dart`
- Copy: `lib/features/widget_release_risk/widget_release_risk_gate_copy.dart`
- Tests: `test/widget_release_risk_gate_test.dart`

## Related docs

- `docs/IOS_WIDGETKIT_SETUP.md`
- `docs/TODAYS_CHECK_WIDGET_QA.md`
- `docs/WIDGET_SHORTCUT_PREP.md`

## Run tests

```bash
cd apps/mobile
flutter test test/widget_release_risk_gate_test.dart
```

Included in `tool/validate_core.sh`.
