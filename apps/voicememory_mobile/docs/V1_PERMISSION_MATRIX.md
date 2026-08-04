# Focused V1 permission matrix

This matrix is the build-time allowlist for the production
Record → transcript → evidence → change → next-recording loop. It must stay in
sync with `V1CapabilityRegistry`, native Release build settings, and
`tool/audit_v1_permissions.sh`.

| Capability | Reachable V1 feature | Startup/plugin source | V1 decision |
| --- | --- | --- | --- |
| Internet | HTTPS transcription and analysis | `http`; capture API | Keep: Android `INTERNET` |
| Microphone | User-initiated voice recording | `record`, `permission_handler` | Keep: Android `RECORD_AUDIO`; iOS `NSMicrophoneUsageDescription`. Request only after the user chooses voice recording. |
| Device authentication | Optional private archive lock | `local_auth`; Security settings | Keep: Android `USE_BIOMETRIC`; iOS `NSFaceIDUsageDescription`. Prompt only when enabling or unlocking the lock. |
| Store billing | Paid ArchiveMe Pro purchase and restore | `purchases_flutter`; Google Play Billing | Keep: Android `com.android.vending.BILLING`. This normal permission is required by the paid RevenueCat build and is not runtime-prompted. |
| Notifications and boot | Check-in reminders and remote push | `flutter_local_notifications`, `firebase_messaging` | Exclude from focused V1. No startup initialization or reachable settings control. |
| Background processing | Queue, connector, briefing, and automation schedulers | `workmanager`, `background_downloader` | Exclude from focused V1. Retry drains in the foreground. |
| Health | HealthKit / Health Connect connector | `health` | Exclude. Connector is not initialized. |
| Bluetooth | Mesh discovery and offload | `flutter_blue_plus`, `flutter_ble_peripheral` | Exclude. Experimental mesh startup is disabled. |
| P2P / WebRTC | Mesh sync and compute offload | `nsd`, `flutter_webrtc` | Exclude. Routes and startup services are unavailable in V1. |
| Local network / Bonjour | mDNS peer discovery | `nsd` | Exclude. No Bonjour services or local-network usage description. |
| Nearby Wi-Fi | Peer discovery | retained experimental native plugins | Exclude. Removed from merged Release manifest. |
| Location | Context and geocoding experiments | `geolocator`, `geocoding` | Exclude. No V1 route or startup service. |
| Calendar | Archive calendar / connector experiments | permission-handler declarations | Exclude. Archive calendar data is local journal chronology, not device Calendar access. |
| Activity recognition | Health/context experiments | health and permission-handler declarations | Exclude. |
| Camera / photos | Scanner and image-memory experiments | `mobile_scanner`, `image_picker` | Exclude. No Release camera/photo usage descriptions. |
| Speech recognition | Apple Speech experiments | retained experimental code | Exclude. Core transcription uses recorded audio, not Apple Speech. |
| App groups / iCloud | Share and widget extensions, cloud documents | native extension targets | Exclude from the focused V1 Runner artifact. |

## Final Release allowlists

- Android: `INTERNET`, `RECORD_AUDIO`, `USE_BIOMETRIC`,
  `com.android.vending.BILLING`.
- iOS usage descriptions: microphone and Face ID.
- iOS Runner entitlements: none.
- Embedded extensions: none.

Experimental source remains development-only. Adding a capability to Release
requires changing this matrix, the compile-time registry, native build files,
artifact audit, tests, and store disclosures together.
