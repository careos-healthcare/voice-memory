# iOS WidgetKit Setup — ArchiveMeWidgets

ArchiveMe provides Quick Capture, Micro-Habit Streak, and Semantic Cluster
Pulse widgets for supported Home and Lock Screen families.

## Prerequisites

1. Open **`ios/Runner.xcworkspace`** (not `Runner.xcodeproj`).
2. In [Apple Developer](https://developer.apple.com/account/resources/identifiers/list):
   - Enable App Groups on the Runner App ID (`com.voicememory.mobile`).
   - Create App Group: **`group.com.voicememory.mobile`**
   - Assign the App Group to Runner, `ShareExtension`, `ArchiveMeWidgets`,
     and the legacy widget App IDs.
   - Enable Keychain Sharing with
     `$(AppIdentifierPrefix)com.voicememory.mobile.shared` for Runner,
     `ShareExtension`, and `ArchiveMeWidgets`.
3. Do not commit provisioning profiles, certificates, or secrets.

## What is already in the repo

| Path | Purpose |
|---|---|
| `ios/Runner/ObjectiveWidgetStorage.swift` | Writes the isolated legacy objective payload as AES-GCM ciphertext |
| `ios/Runner/AppDelegate.swift` | MethodChannel `archive_me/current_objective_widget` |
| `ios/Runner/Runner.entitlements` | App Group for Runner |
| `ios/ShareExtension/` | Encrypted text, URL, image, and file share target |
| `ios/ArchiveMeWidgets/` | Quick capture, micro-habit, and cluster widgets |
| `ios/SharedIntegration/SecureAppGroupStore.swift` | AES-GCM handoff with process locking |
| `ios/TodayCheckWidget/TodayCheckWidget.swift` | Inactive legacy objective widget retained for history |
| `ios/TodayCheckWidget/Info.plist` | Extension plist |
| `ios/TodayCheckWidget/TodayCheckWidgetExtension.entitlements` | App Group for widget |

The `ShareExtension` and `ArchiveMeWidgets` targets are already embedded in
`Runner.xcodeproj`. Signing still requires matching App IDs and provisioning
profiles in the Apple Developer account.

## Verify extension targets

1. Open `ios/Runner.xcworkspace`.
2. Confirm the `ShareExtension` and `ArchiveMeWidgets` targets are present.
3. **Signing & Capabilities** for Runner and both extensions:
   - Add App Groups capability
   - Check **`group.com.voicememory.mobile`**
   - Add Keychain Sharing with the shared access group above.
4. Use iOS 16 or later for Lock Screen widgets. Interactive habit completion
   is available on iOS 17 or later; older versions deep-link to the app.
5. Build scheme: select **Runner** (extensions embed automatically).

## Encrypted payload contract

`MemoryGraphWidgetService` sends a bounded snapshot to Runner. Runner writes it
through `SecureAppGroupStore` as AES-GCM ciphertext under `widget/current`;
the shared Keychain key is never stored in App Group defaults or plaintext
files. The active snapshot includes:

- `schemaVersion`, `generatedAt`, `theme`, and `lockScreenEnabled`
- `quickCapture` and its deep-link route
- up to three `habits`, plus a flattened `habitStreak`
- up to three `clusters`, plus a flattened `clusterPulse`

The legacy current-objective bridge uses the separate encrypted
`objective-widget/current` record and cannot overwrite the active graph
snapshot. After save/clear, Runner calls
`WidgetCenter.shared.reloadAllTimelines()`.

## Deep link

Widget tap uses URL scheme **`archiveme://record`** (also registered in Runner `Info.plist`).
Existing scheme **`voicememory://`** still works.

AppDelegate captures the route and Flutter reads it via `consumePendingWidgetRoute`.

## Build

```bash
cd apps/voicememory_mobile
flutter build ios --debug --no-codesign
```

For device/TestFlight, archive from Xcode with valid signing + App Group provisioning.

## Troubleshooting

| Issue | Fix |
|---|---|
| Widget shows default copy only | App Group or shared Keychain group not enabled on both targets |
| Widget never updates | Confirm `reloadAllTimelines` runs; re-open app after check change |
| Tap opens app but not Record | Confirm `archiveme` URL scheme in Info.plist; check router pending route |
| TestFlight widget stale | iOS may delay timeline refresh; force-quit and reopen app |
| Codesign error on App Group | Regenerate provisioning profiles with App Group enabled |

## TestFlight checklist

1. Enable App Group in Developer portal + Xcode capabilities.
2. Archive Runner with embedded `ArchiveMeWidgets` extension.
3. Upload to TestFlight.
4. Install on device and add all three widget kinds.
5. Confirm Lock Screen surfaces show `Private` until explicitly enabled.
6. Complete a habit and confirm the graph updates on the next app wake.
7. Tap Quick Capture and confirm Record opens.
