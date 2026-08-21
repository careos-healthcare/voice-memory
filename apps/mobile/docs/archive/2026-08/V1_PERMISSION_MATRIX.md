# V1 permission matrix

Generated contract for the focused ArchiveMe V1 release. Keep aligned with:

- `lib/core/config/v1_capability_registry.dart`
- `tool/audit_v1_permissions.sh`
- Android manifest and iOS Info.plist / entitlements

## Enabled capabilities

| Capability | Android | iOS | Runtime use |
|------------|---------|-----|-------------|
| Microphone | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` | Voice capture |
| Biometric app lock | `USE_BIOMETRIC` | `NSFaceIDUsageDescription` | Optional archive lock |
| Network | `INTERNET` | ATS default | Encrypted sync + remote processing (consent-gated) |
| Store billing | Play Billing | StoreKit via RevenueCat | Optional paid deeper history |
| On-device speech (native bridge) | — | `NSSpeechRecognitionUsageDescription` | Optional native transcription bridge |

## Explicitly disabled (must not appear in release binary)

| Capability | Registry flag | Requirement |
|------------|-----------------|-------------|
| Push / local notifications | `notifications = false` | No notification permission keys, no `ScheduledNotificationBootReceiver`, no `flutter_local_notifications` in `pubspec.yaml` or `lib/` imports, no schedulers initialized at startup |
| Native extensions (widgets) | `nativeExtensions = false` | No WidgetKit target, no App Group entitlement, no widget receiver in Android manifest, no widget method channel |
| Background processing | `backgroundProcessing = false` | No background modes for sync |
| Health / Bluetooth / Location | `false` | No related permissions |
| Camera / Photos | `cameraAndPhotos = false` | No camera/photo keys |
| Live voice / WebRTC | `liveVoice = false`, `p2pAndWebRtc = false` | No live audio routes in V1 router |

Historical widget source lives under `experiments/archive/today_check_widget/` and must not be compiled or registered in release targets.

Upgrade path: `ExcludedNativeCapabilityCleanup` clears legacy widget title/body/check-question keys from Flutter prefs and native shared storage without touching the encrypted archive.

## Validation

Run locally:

```bash
cd apps/mobile
bash tool/audit_v1_permissions.sh
bash tool/validate_v1_production_graph.sh
flutter test test/beta_release_artifacts_test.dart test/excluded_native_capability_cleanup_test.dart test/widget_release_risk_gate_test.dart
```

CI runs both scripts in the ArchiveMe stabilization workflow.
