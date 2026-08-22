# Caregiver Monitoring Mode — governance

> **Status: implemented but not V1-shipped.**
>
> Compile-time off by default (`VOICEMEMORY_ENABLE_CAREGIVER_MODE=false`). Real UI and
> server consent verification exist; routes are unreachable until the flag is enabled.

> ### Before enabling the flag, read [../../security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md](../../security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md)
>
> This file is the design and governance record and lives under `docs/archive/`.
> The blocking preconditions live in `docs/security/` so they are found by
> someone about to ship rather than only by someone reading history. In short:
> there are still no capability checks on export, bulk export, data portability,
> or audio playback, so the read-only limits remain a property of which buttons
> the shared screens draw. Revocation is no longer among the gaps —
> `POST /api/coach/consent/revoke` records revocations in Postgres and both
> server `verify` paths consult that list on every call, failing closed if it
> cannot be read — and the default TTLs are now 7 days (caregiver) and 30 days
> (coach) from a single declaration per role. Enabling the flag before the
> capability checks land still turns the remaining gap into a live safety
> problem.

Caregiver monitoring is a **separate persona gate** — not bundled into
`VOICE_MEMORY_ENABLE_BETA_SURFACES` and not covered by the insight-quality CI gate alone.

## Bar this feature must meet (same as theory tracking / image evidence)

| Check | Theory tracking | Image evidence | Caregiver monitoring |
|---|---|---|---|
| Compile-time flag (default off) | `VOICEMEMORY_ENABLE_THEORY_TRACKING` | `VOICEMEMORY_ENABLE_IMAGE_EVIDENCE` + beta master | `VOICEMEMORY_ENABLE_CAREGIVER_MODE` |
| Capability registry | `/theories` in nav guard | beta + image flags | `V1CapabilityRegistry.caregiverMonitoring` |
| Real wired UI (not flag-only) | `TheoriesScreen` | `ImageEvidenceAttachmentPanel` | `CaregiverDashboardView`, `ConsentRequestView` |
| Route guard | `V1NavigationGuard` | beta surfaces | flag-gated `/caregiver*` |
| Module registry | `theory` modules | `image_evidence` | `caregiver` in `v1_registered_feature_modules.txt` |
| Fail-closed security | N/A | camera permission off in V1 | server HMAC consent; no local signing |

Internal insight-science modules (`insight-ingredient-optimizer`, `a-tier-prioritization`) stay
deferred per [InsightScienceDeferredGuard](../lib/core/config/insight_science_deferred_guard.dart).

## Architecture

```text
CaregiverFeatureFlags (compile-time, default false)
  → V1NavigationGuard / CaregiverModeController (block routes + mode transitions)
  → ConsentRequestView (multi-step consent UI)
  → ConsentVerificationService → POST /api/coach/consent/verify (caregiver domain)
  → CaregiverDashboardView + CaregiverReadService (read-only, audited)
```

Shared types: `packages/shared/types/caregiver.ts`

## Enable locally

```bash
flutter run --dart-define=VOICEMEMORY_ENABLE_CAREGIVER_MODE=true
```

Backend must have `CAREGIVER_CONSENT_HMAC_SECRET` configured (see API coach consent routes).

## Ship checklist (before V1 or public beta)

- [ ] End-to-end consent: grant → server verify → dashboard read with audit log
- [ ] Deep links to `/caregiver` redirect to Record when flag off
- [ ] No settings/account nav entry without flag — the two Settings-list entries
      are now gated on `V1CapabilityRegistry.caregiverMonitoring`, but the
      pillar-4 caregiver section of `privacy_security_screen.dart` is still
      ungated and still mounts its own grants list. See the discoverability gate
      and "remaining consolidation step" sections of the blockers doc.
- [ ] Permission matrix + production graph validators green
- [ ] Explicit product sign-off separate from beta surfaces bundle
- [ ] **All five blockers in
      [CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md](../../security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md)
      closed** — capability checks, revoke endpoint + server revocation list,
      shorter TTLs, `observer` implemented or deleted, copy re-checked

## Key files

| Layer | Path |
|---|---|
| Feature flag | `lib/features/caregiver/caregiver_feature_flags.dart` |
| Mode + audit | `lib/features/caregiver/caregiver_mode_controller.dart` |
| Server consent | `lib/features/caregiver/consent_verification_service.dart` |
| Dashboard UI | `lib/features/caregiver/views/caregiver_dashboard_view.dart` |
| Consent UI | `lib/features/caregiver/views/consent_request_view.dart` |
| Tests | `test/caregiver_*_test.dart` |
