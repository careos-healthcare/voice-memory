# Sharing risk register

Tracks risks for **future** sharing work. No sharing feature is live today.

| ID | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R1 | Copy implies diagnosis or treatment | Medium | High | `SafeSharingCopy` + banned-term tests; legal review before ship |
| R2 | User shares more than intended | Medium | High | Explicit preview; section picker; no default "share all" |
| R3 | Therapist/coach dashboard expectation | Medium | High | Ban "therapist dashboard"; future-only docs |
| R4 | Shared link persists after revoke | Low | High | Time-limited links; revoke path in design spec |
| R5 | Transcript leaked via analytics | Low | High | No transcript in share analytics; metadata only |
| R6 | Confusion with medical records | Medium | High | Never use "medical record"; disclaimer on every share surface |
| R7 | Auto-share on new entries | Low | Critical | Opt-in only; no background share jobs |
| R8 | Regulatory adjacency (HIPAA, etc.) | Low | Critical | No clinical positioning; not a care product |
| R9 | Beta users assume feature is live | Medium | Medium | "Future"/"planned" in all pre-ship copy |
| R10 | Export handoff confused with secure sharing | Medium | Medium | Separate labels: export file vs future in-app share |

## Protected areas (do not change for foundation v1)

- Backend, sync, permissions, contacts
- RevenueCat, product IDs, entitlements, restore
- Signing, build numbers, notifications
- Journal storage, proof thresholds, evidence gates
- AI chat

## Foundation v1 scope

- Documentation in `docs/sharing/`
- Copy/model in `lib/features/safe_sharing/`
- Tests in `test/safe_sharing_copy_test.dart`
- **No** UI, network, or storage changes
