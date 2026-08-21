# iOS WidgetKit Setup — Today\u2019s Check

ArchiveMe keeps one useful check ready on the iOS home screen.

## Prerequisites

1. Open **`ios/Runner.xcworkspace`** (not `Runner.xcodeproj`).
2. In [Apple Developer](https://developer.apple.com/account/resources/identifiers/list):
   - Enable App Groups on the Runner App ID (`com.voicememory.mobile`).
   - Create App Group: **`group.com.voicememory.mobile`**
   - Assign the App Group to Runner and the widget extension App ID.
3. Do not commit provisioning profiles, certificates, or secrets.

## What is already in the repo

| Path | Purpose |
|---|---|
| `ios/Runner/ObjectiveWidgetStorage.swift` | Writes payload to App Group UserDefaults |
| `ios/Runner/AppDelegate.swift` | MethodChannel `archive_me/current_objective_widget` |
| `ios/Runner/Runner.entitlements` | App Group for Runner |
| `ios/TodayCheckWidget/TodayCheckWidget.swift` | WidgetKit UI + timeline |
| `ios/TodayCheckWidget/Info.plist` | Extension plist |
| `ios/TodayCheckWidget/TodayCheckWidgetExtension.entitlements` | App Group for widget |

The **Widget extension target is not auto-added** to avoid corrupting `project.pbxproj`.
Follow the steps below once in Xcode.

## Add Widget Extension target (one-time)

1. Open `ios/Runner.xcworkspace`.
2. **File → New → Target… → Widget Extension**.
3. Product name: **`TodayCheckWidget`**
4. Bundle identifier: **`com.voicememory.mobile.TodayCheckWidget`**
5. Uncheck “Include Configuration Intent” (static widget only).
6. Delete the auto-generated Swift file Xcode creates.
7. Add existing files to the extension target:
   - `ios/TodayCheckWidget/TodayCheckWidget.swift`
   - `ios/TodayCheckWidget/Info.plist` (set as extension Info.plist if needed)
8. Set **Code Signing Entitlements** to
   `TodayCheckWidget/TodayCheckWidgetExtension.entitlements`.
9. **Signing & Capabilities** for **Runner** and **TodayCheckWidget**:
   - Add App Groups capability
   - Check **`group.com.voicememory.mobile`**
10. Deployment target: **iOS 14.0** minimum (WidgetKit).
11. Build scheme: select **Runner** (widget embeds automatically).

## Widgets included

| Widget | Families | Tap action |
|---|---|---|
| **Today\u2019s check** | `systemSmall` | Opens pending check route (default `/record`) |
| **Quick capture** | `systemSmall`, accessory circular/rectangular | Always opens `/record` |

Both widgets read the shared App Group payload written by `buildWidgetPayload()`.

## Payload contract

Dart `buildWidgetPayload()` writes these string keys to App Group UserDefaults:

- `title`
- `body`
- `checkQuestion`
- `primaryActionLabel`
- `route`
- `type`
- `updatedAt`

After save/clear, Runner calls `WidgetCenter.shared.reloadAllTimelines()`.

## Deep link

Widget tap uses URL scheme **`archiveme://record`** (also registered in Runner `Info.plist`).
Existing scheme **`voicememory://`** still works.

AppDelegate captures the route and Flutter reads it via `consumePendingWidgetRoute`.

## Build

```bash
cd apps/mobile
flutter build ios --debug --no-codesign
```

For device/TestFlight, archive from Xcode with valid signing + App Group provisioning.

## Troubleshooting

| Issue | Fix |
|---|---|
| Widget shows default copy only | App Group not enabled on both targets |
| Widget never updates | Confirm `reloadAllTimelines` runs; re-open app after check change |
| Tap opens app but not Record | Confirm `archiveme` URL scheme in Info.plist; check router pending route |
| TestFlight widget stale | iOS may delay timeline refresh; force-quit and reopen app |
| Codesign error on App Group | Regenerate provisioning profiles with App Group enabled |

## TestFlight checklist

1. Enable App Group in Developer portal + Xcode capabilities.
2. Archive Runner with embedded TodayCheckWidget extension.
3. Upload to TestFlight.
4. Install on device → add widget → set check in app → confirm update.
5. Tap widget → confirm Record opens.
6. Trial reset → confirm safe default copy.
