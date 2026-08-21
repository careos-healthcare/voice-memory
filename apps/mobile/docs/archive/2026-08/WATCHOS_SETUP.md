# watchOS Companion — Quick Record (SCAFFOLDING)

> **Status: in-progress scaffolding — not V1-shipped.**
>
> Source files and the WCSession bridge exist, but the watchOS **Xcode target is manual**
> (see below) and Flutter ingest is **off by default** via
> `VOICEMEMORY_ENABLE_WATCH_COMPANION=false`. Do not treat this as a production surface
> until the checklist at the bottom passes.

ArchiveMe includes a standalone Apple Watch companion scaffold for one-tap quick record and WCSession audio sync back to the host iOS app.

## What is actually wired

| Layer | File | Status |
|---|---|---|
| watchOS record + send | `ios/WatchApp/WatchConnectivityManager.swift` | Scaffold — needs Watch target in Xcode |
| iOS WCSession inbox | `ios/Runner/WatchSessionBridge.swift` | **Active** — `AppDelegate` always calls `activate()` |
| Method channel | `archive_me/watch_session` in `AppDelegate.swift` | **Active** |
| Flutter bridge | `lib/features/watch_companion/watch_connectivity_service.dart` | **Implemented** — wraps `WatchSessionBridge` on `archive_me/watch_session` |
| Ingest pipeline | `watch_audio_ingest_service.dart` → `CapturePipelineService.runWatchCapture()` | **Implemented** |
| Startup hook | `WatchSessionCoordinator` in `v1_startup_coordinator.dart` | **Gated** — only when `V1CapabilityRegistry.watchCompanion` |
| UI feedback | `WatchCaptureIngestHost` in `app.dart` | **Implemented** (snackbar on ingest) |

```text
Watch QuickRecordView
  → WatchConnectivityManager.transferFile(m4a)
    → Runner WatchSessionBridge (WCSessionDelegate)
      → MethodChannel watchAudioReceived
        → Flutter WatchSessionBridge  [requires VOICEMEMORY_ENABLE_WATCH_COMPANION]
          → WatchAudioIngestService → journal entry (captureSource: watch)
```

### Why a repo search for "WatchConnectivity" finds zero Dart hits

Dart uses **`WatchSession*`** naming (`WatchSessionBridge`, `WatchSessionCoordinator`).
The watch-side class is Swift-only (`WatchConnectivityManager`).

## Enable for local development

```bash
flutter run --dart-define=VOICEMEMORY_ENABLE_WATCH_COMPANION=true
```

Registry: `lib/core/config/watch_companion_feature_flags.dart` → `V1CapabilityRegistry.watchCompanion`.

## Prerequisites

1. Open **`ios/Runner.xcworkspace`**.
2. Apple Developer: enable WatchKit App + WatchKit Extension for `com.voicememory.mobile`.
3. Do not commit provisioning profiles or certificates.

## What is already in the repo

| Path | Purpose |
|---|---|
| `ios/WatchApp/WatchApp.swift` | watchOS app entry + quick record UI |
| `ios/WatchApp/QuickRecordView.swift` | High-contrast one-tap record/stop |
| `ios/WatchApp/WatchConnectivityManager.swift` | AVAudioRecorder + `WCSession.transferFile` |
| `ios/WatchApp/ArchiveMeComplication.swift` | WidgetKit complication scaffold |
| `ios/WatchApp/Info.plist` | Watch app plist |
| `ios/WatchApp/WatchApp.entitlements` | App Group (shared with Runner) |
| `ios/Runner/WatchSessionBridge.swift` | Host-side WCSession inbox |
| `ios/Runner/AppDelegate.swift` | Method channel `archive_me/watch_session` |
| `lib/features/watch/watch_session_bridge.dart` | Flutter bridge for received audio paths |

The **Watch target is not auto-added** to avoid corrupting `project.pbxproj`. Follow the steps below once in Xcode.

## Add Watch App target (one-time)

1. **File → New → Target… → Watch App for iOS App**.
2. Product name: **`ArchiveMeWatch`**
3. Bundle identifier: **`com.voicememory.mobile.watchkitapp`**
4. Delete Xcode-generated Swift files.
5. Add existing files from `ios/WatchApp/` to the Watch target.
6. Set Watch app Info.plist to `ios/WatchApp/Info.plist`.
7. Set entitlements to `ios/WatchApp/WatchApp.entitlements`.
8. Add **`WatchSessionBridge.swift`** to the Runner target (if not already compiled).
9. Enable App Groups on Runner + Watch: **`group.com.voicememory.mobile`**
10. Add a **Watch Widget Extension** target and include `ArchiveMeComplication.swift` for complications.

## WCSession contract

Watch sends files with metadata:

```json
{
  "type": "watch_audio_capture",
  "capturedAt": "<ISO8601>",
  "filename": "watch_capture_<epoch>.m4a",
  "durationSeconds": 12
}
```

Runner copies files into a temp inbox and exposes structured payloads to Flutter via:

- `consumePendingWatchAudio` → `[{ path, durationSeconds, capturedAt }]`
- event `watchAudioReceived`

## Flutter ingest pipeline

1. `WatchSessionBridge` receives native payloads.
2. `WatchAudioIngestService` dedupes and serializes ingest.
3. `CapturePipelineService.runWatchCapture()` stages audio, transcribes/analyzes when allowed, and stamps `captureSource: watch`.
4. `WatchCaptureIngestHost` shows a snackbar when ingest completes.

## Ship checklist (before removing SCAFFOLDING banner)

- [ ] Watch target embedded in Runner.xcodeproj and builds on device
- [ ] End-to-end: watch record → iPhone snackbar → journal entry with `captureSource: watch`
- [ ] `VOICEMEMORY_ENABLE_WATCH_COMPANION` default reviewed for release
- [ ] Registered in `v1_production_allowlist` / permission matrix if promoted to V1

## Build

```bash
cd apps/mobile
flutter build ios --debug --no-codesign
```

Archive Runner + embedded Watch app from Xcode for device/TestFlight builds.
