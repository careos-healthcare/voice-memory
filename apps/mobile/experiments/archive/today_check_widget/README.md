# Today Check widget (archived)

Historical home-screen widget and App Group bridge source for ArchiveMe.

**Not compiled or registered in focused-beta releases.** `V1CapabilityRegistry.nativeExtensions`
and `V1CapabilityRegistry.notifications` are `false` for V1.

Restore only after re-enabling the capability registry flags, updating privacy docs, and
passing `tool/run_widget_release_risk_gate.sh`.

Contents:
- `android/widget/` — `TodayCheckWidgetProvider`, `ObjectiveWidgetStorage`
- `android/today_check_widget.xml`, `today_check_widget_info.xml`
- `ios/TodayCheckWidget/` — WidgetKit extension source (never shipped as a build target)
- `ios/ObjectiveWidgetStorage.swift` — App Group UserDefaults bridge
