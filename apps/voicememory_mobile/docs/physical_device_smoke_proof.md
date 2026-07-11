# Physical device smoke proof v1

Real-device smoke proof checklist for **iPhone and iPad** before TestFlight or App Store submission. Proof/checklist only — no feature changes.

## Decisions

| Decision | Meaning |
| --- | --- |
| `proved` | All 19 checks pass on device |
| `manualRequired` | Automated/repo checks pass; device steps still pending |
| `blocked` | Earliest check failed |

## Checklist (19)

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
```

## Run release smoke bundle

```bash
cd apps/voicememory_mobile
bash tool/run_physical_device_release_smoke.sh
```

Manual device QA still required for pending capture, permission, purchase, and restore steps.
