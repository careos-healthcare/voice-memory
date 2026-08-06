# V1 permission matrix

Generated contract for the focused ArchiveMe V1 release. Keep aligned with:

- `lib/core/config/v1_capability_registry.dart`
- `tool/audit_v1_permissions.sh`
- Android manifest and iOS Info.plist

## Enabled capabilities

| Capability | Android | iOS | Runtime use |
|------------|---------|-----|-------------|
| Microphone | `RECORD_AUDIO` | `NSMicrophoneUsageDescription` | Voice capture |
| Biometric app lock | `USE_BIOMETRIC` | `NSFaceIDUsageDescription` | Optional archive lock |
| Network | `INTERNET` | ATS default | Encrypted sync + remote processing (consent-gated) |
| Store billing | Play Billing | StoreKit via RevenueCat | Optional paid deeper history |

## Explicitly disabled (must not appear in native config)

| Capability | Registry flag | Requirement |
|------------|-----------------|-------------|
| Push notifications | `notifications = false` | No notification permission keys |
| Background processing | `backgroundProcessing = false` | No background modes for sync |
| Health / Bluetooth / Location | `false` | No related permissions |
| Camera / Photos | `cameraAndPhotos = false` | No camera/photo keys |
| Speech recognition (on-device OS) | `speechRecognition = false` | No `NSSpeechRecognitionUsageDescription` |
| Live voice / WebRTC | `liveVoice = false`, `p2pAndWebRtc = false` | No live audio routes in V1 router |

## Validation

Run locally:

```bash
cd apps/voicememory_mobile
bash tool/audit_v1_permissions.sh
bash tool/validate_v1_production_graph.sh
```

CI runs both scripts in the ArchiveMe stabilization workflow.
