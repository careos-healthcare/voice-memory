# Physical device smoke proof v1

Real-device smoke proof checklist for **iPhone and iPad** before TestFlight or App Store submission. Proof/checklist only — no feature changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `proved` | All 25 checks pass on device |
| `manualRequired` | Automated/repo checks pass; device steps still pending |
| `blocked` | Earliest check failed |

## Checklist (25)

1. Fresh install opens
2. App name ArchiveMe
3. Launch screen OK
4. Mic permission accept path
5. Mic permission deny path
6. Typed save
7. Voice save
8. Transcript appears
9. Post-save reinforcement appears
10. First proof path
11. Correction path
12. Pro screen opens
13. RevenueCat product load
14. Purchase unavailable copy safe when key missing
15. Restore path opens
16. Privacy, terms, and support routes open
17. Offline launch safe
18. No crash
19. No private text leaked in logs
20. `/future-preview` completes all three stages at default text
21. `/future-preview` stages and sheets remain scrollable at the largest Accessibility text size
22. `/archive-search` initial state, keyboard, results, loading, and error actions remain reachable at default text
23. `/archive-search` remains scrollable with no clipped controls at the largest Accessibility text size
24. `/life-os/graph` controls, canvas/list, and node detail remain reachable at default text
25. `/life-os/graph` controls, list, and detail remain scrollable at the largest Accessibility text size

For checks 20–25, verify portrait and landscape, confirm interactive controls
have comfortable 44-point targets, and check that content stays outside the
notch/Dynamic Island and home indicator.

## Key rules

- **Proof/checklist only**
- **No feature changes**
- Do not change capture flow or paywall mechanics while running smoke proof

## Repo signal bridge

`PhysicalDeviceSmokeProof.fromRepoSignals()` verifies static routes, copy, Info.plist name, launch screen, log privacy policy, and purchase-unavailable fallback without changing runtime behavior.

## Code modules

- Engine: `lib/features/physical_device_smoke/physical_device_smoke_proof.dart`
- Copy: `lib/features/physical_device_smoke/physical_device_smoke_proof_copy.dart`
- Tests: `test/physical_device_smoke_proof_test.dart`

## Run tests

```bash
cd apps/voicememory_mobile
flutter test test/physical_device_smoke_proof_test.dart
flutter test test/ios_device_layout_matrix_test.dart
```

The host matrix uses modeled logical viewports and is regression coverage only.
It is not physical-device proof.

## Run the iOS simulator/device layout audit

List runners with `flutter devices`, then run against the selected iPhone:

```bash
cd apps/voicememory_mobile
flutter test integration_test/ios_device_layout_audit_test.dart -d <device-id>
```

The integration test reads the runner's actual `MediaQuery` safe area, opens
`/future-preview`, `/archive-search`, and `/life-os/graph`, checks for Flutter
layout exceptions, and captures screenshots through the integration-test
runner.

Run it once at the default text size. Then set the simulator/device in
**Settings > Accessibility > Display & Text Size > Larger Text** to the largest
Accessibility size and rerun with the guard enabled:

```bash
flutter test integration_test/ios_device_layout_audit_test.dart \
  -d <device-id> \
  --dart-define=IOS_LAYOUT_REQUIRE_ACCESSIBILITY_TEXT=true
```

Rotate the runner to landscape and repeat both runs. A simulator run validates
the simulator window; final TestFlight sign-off still requires a physical
iPhone. Physical-device execution may require selecting the development team
and signing profile in `ios/Runner.xcworkspace`.

## Run release smoke bundle

```bash
cd apps/voicememory_mobile
bash tool/run_physical_device_release_smoke.sh
```

Manual device QA still required for pending capture, permission, purchase, and restore steps.
