# ArchiveMe release readiness

This is the single launch-status index. Linked documents contain details and
evidence; this file does not duplicate their checklists.

The authoritative backend and Android/iOS automation is
`.github/workflows/build_and_deploy.yml`; ownership, dependency ordering, and
the API-only release boundary are documented in
`docs/FLUTTER_V1_RELEASE_PIPELINE.md`. `.github/workflows/flutter_ci.yml` is
pull-request CI only.

| Gate | Status | Evidence |
| --- | --- | --- |
| Pull-request CI | NOT RUN | `.github/workflows/flutter_ci.yml`; confirm the required GitHub check on the candidate SHA |
| Android signed artifact | BLOCKED | `docs/ANDROID_RELEASE_CHECKLIST.md`; no production keystore/certificate evidence is available in this workspace |
| iOS signed build | BLOCKED | `docs/IOS_RELEASE_CHECKLIST.md`; no signed archive evidence is available in this workspace |
| V1 permission audit | PASS | 2026-07-30: `tool/audit_v1_permissions.sh` passed against the merged Android Release manifest and built unsigned iOS Release app |
| RevenueCat automated configuration/tests | PASS | 2026-07-30: 84 focused RevenueCat, paywall, restore, cache, and entitlement tests passed |
| RevenueCat physical-device proof | BLOCKED | `docs/REVENUECAT_PHYSICAL_DEVICE_PROOF.md` contains no passing transaction evidence |
| Privacy disclosures | NOT RUN | `docs/PRIVACY_CHECKLIST.md` |
| Store metadata | NOT RUN | `APP_STORE_SUBMISSION_PACK.md`, `docs/APP_STORE_COPY.md`, `docs/PLAY_STORE_COPY.md` |
| Final physical-device smoke test | BLOCKED | `docs/TESTFLIGHT_MANUAL_QA.md`; no passing physical-device evidence is stored |
| TestFlight upload | BLOCKED | No App Store Connect upload evidence |
| Play Internal upload | BLOCKED | No Google Play Internal upload evidence |

## Decision

**BLOCKED for paid launch.** Automated checks can reduce code and configuration
risk, but cannot replace the missing iOS and Android store-sandbox purchase,
restore, expiry, signing, upload, and final smoke evidence.

Older release/readiness documents are supporting or historical detail. If a
status conflicts with this file, this file and its linked evidence take
precedence.
