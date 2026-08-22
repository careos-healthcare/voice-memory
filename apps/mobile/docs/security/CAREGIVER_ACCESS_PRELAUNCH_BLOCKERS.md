# Caregiver & coach access — hard pre-launch blockers

> **Read this before flipping `VOICEMEMORY_ENABLE_CAREGIVER_MODE`.**
>
> Every item below is a **blocker**, not a follow-up. The feature is wired end to
> end and looks finished; what was missing is enforcement. On-device capability
> checks, per-scope consent enforcement and audio playback have landed. What is
> left is a role that nothing writes, and one revoke string that now understates
> what revoking does.

## Status

| Blocker | State |
|---|---|
| 1 — capability checks keyed to the session role | **Closed on device**, including audio playback |
| 2 — revoke endpoint and server-side revocation list | **Closed** |
| 3 — shorten and consolidate the stateless TTLs | **Closed** |
| 4 — implement or delete `MultiPartyAccessRole.observer` | **Open** |
| 5 — re-check the copy against whatever enforcement ships | **Mostly closed** — the read-only limit strings are rewritten; the caregiver revoke strings are not |

Blockers 2 and 3 were closed together, because they trade against each other:
with revocation enforced server-side, TTL is no longer the only thing standing
between a withdrawn grant and a working one, so the new lifetimes are set for
re-consent cadence rather than for worst-case exposure.

Caregiver access decides whether another person can read a mental-health
journal, and a caregiver can be the person the writer is least free to say no
to. The failure mode is not a rough edge — it is a controlling family member
keeping a working token for a month after being told they no longer have access.

## Why this file exists separately from the governance doc

`docs/archive/2026-08/CAREGIVER_MONITORING.md` is the design and governance
record, and it sits under `docs/archive/`. Archived material is read when someone
goes looking for history; a ship gate has to be found by someone who is *not*
looking. This file lives in `docs/security/` next to
[SQLCIPHER_KEY_MODEL.md](./SQLCIPHER_KEY_MODEL.md) because it is a security
precondition, and it is linked from the code that would carry the risk:

- `lib/features/auth/domain/caregiver_access_copy.dart` (the user-facing claims)
- `lib/screens/settings_screen.dart` (the gated nav entry)

## Blocker 1 — capability checks keyed to the active session role

**Status: closed on device. Nothing equivalent exists server-side** — see the
scope note at the end of this section before touching any copy.

`CaregiverSessionGuard` (`lib/security/caregiver_session_guard.dart`) resolves
the active persona and denies owner-only surfaces to anything that is not the
owner. It is called from the service layer, not from widget builds, so a new
screen cannot reach the data by not knowing about it:

| Surface | Gate |
|---|---|
| `/export` (sanitized archive JSON) | `PrivateDataService.buildSanitizedExport` |
| `/journal-export` (bulk JSON) | `JournalBulkExportService.buildExport` |
| Account data portability ZIP | `AccountDataPortabilityService.buildZipExport` |
| Raw journal JSON | `JournalService.exportJson` |
| Encrypted `.archiveme` backup | `EncryptedCloudBackupService.exportBackup` |
| Manual local backup JSON | `LocalBackupRestoreService.exportBackup` |
| Selected-entries markdown | `SelectedArchiveExport.buildOwnerMarkdown` |
| Every capture write | `CapturePipelineService` (sole caller of `CapturePipelineFacade`) |
| Captured-file playback | `PlaybackService.playFile` |
| Theory citation playback | `CitationPlaybackLauncher.play` |

It fails closed: once the capability is compiled in, a persona that cannot be
read — an unloaded controller, an unreadable prefs record, a throwing lookup —
is treated as a caregiver, not as the owner. With the capability compiled out
the guard short-circuits to allow without touching storage, so it costs nothing
today.

Route isolation is live. `CaregiverModeController.redirectFor` used to be dead
code (`tryRedirectFor` had no caller) and named only the shell routes; it is now
called from `app_router.dart` and is a **whitelist** — an active caregiver
session reaches `/caregiver` and `/caregiver/consent` and nothing else, so a
route added later is isolated by default rather than by being remembered.

**Neither whitelisted path is a registered route.** `RouteCatalog.caregiverHome`
(`/caregiver`) and `RouteCatalog.caregiverConsent` (`/caregiver/consent`) are
declared, and `app_router.dart` registers no `GoRoute` at either. The two
widgets that would serve them — `CaregiverDashboardView` and
`ConsentRequestView` — are constructed by nothing in `lib/`. So the whitelist
currently redirects an active caregiver session to a path that does not
resolve, and there is no caregiver-session UI at all. This makes the isolation
*more* conservative rather than less, and it is not a blocker, but it does mean
no copy on those two views is reachable and none of it can be cited as evidence
of anything. Anything that ships those routes has to re-check every string on
them against what Blocker 1 actually enforces.

### Two consent choices were decorative

`thresholdAlerts` and `reviewSummaries` are signed into the token
(`packages/shared/lib/caregiver/consent-verification.ts:50-51`), and neither was
ever read by a gate:

- The alerts stream was **exempted by name** in `ensureReadAllowed`
  (`… && streamId != CaregiverPermissions.insightAlertsStream`). The exemption
  existed because `insight_alerts` is a pseudo-stream that nothing writes into
  `evidenceStreamIds`, so the membership test `allowsStream` could only ever
  deny it. Declining alerts shared them anyway.
- `reviewSummaries` had no gate at all — no stream id, no reader.

`CaregiverPermissions.allowsStream` is now the single authoritative gate and
resolves both pseudo-streams against their booleans, with the boolean
outranking list membership and an unknown id denying. `CaregiverReadService`
also **honours** the gate results it used to compute and discard.

**No reachable screen offers either choice.** They were offered at the consent
prompt in `consent_request_view.dart`, which nothing constructs. The consent
form that the live grant flow does reach,
`CaregiverConsentForm` (`lib/features/caregiver_grant/`), never mentions
`thresholdAlerts` or `reviewSummaries`. So both scopes are set only by whatever
issues the token, and the gate above decides what they mean. Do not describe
either as something the archive owner picks until a reachable screen asks.

Residual: a declined `proof_trail` records an `access_denied` row but withholds
nothing, because there is no caregiver dashboard rendering anywhere —
`CaregiverDashboardView` is never constructed and `/caregiver` is not a
registered route. Bind the result before rendering any proof-trail data.

### Audio playback — now gated

Original recording audio is a step in kind past what the dashboard offers.
Counts, 72-character excerpts and summaries are the writer's words filtered;
the recording is their voice, unedited, including whatever was said around the
part that got quoted. Both production playback entry points now assert the
guard as their first statement:

- `PlaybackService.playFile` (`lib/audio/playback_service.dart`) — the shared
  file-playback boundary. The guard sits **ahead of the `_disposed || _testMode`
  early return** as well as outside the `try`, so a refusal cannot be delivered
  as "nothing happened" any more than as an ordinary playback error.
- `CitationPlaybackLauncher.play`
  (`lib/features/archive_theory/citation_playback_launcher.dart`, real path
  `retired_sprawl/lib_features/archive_theory/`) — the play-at-timestamp path
  behind a theory citation, reached from `theories_screen.dart`. The guard runs
  before the quote is inspected, so a refusal is not confused with "this
  citation has no audio".

Surveyed and deliberately not gated:

- `AudioDebugActions.playRecording` / `.shareRecording`
  (`lib/features/voice_capture/audio/audio_debug_actions.dart`) plays and
  shares a capture file, and is reached from
  `post_save_recorded_summary_card.dart`. Both methods return on `!kDebugMode`,
  so neither exists in a shipped build. It should still get the guard when that
  file is next touched — it is the one remaining audio *export*.
- `WatchAudioDurationEstimator.estimateSeconds` constructs a player but calls
  `setSourceDeviceFile` and `getDuration` without ever calling `play`, and runs
  on the watch-inbox ingest path, whose write is already gated by
  `CapturePipelineService.runWatchCapture`.
- Live PCM (`PlaybackService.feedLivePcm` / `prepareLiveSession`) carries
  synthesized speech and live-session output, not stored recordings, and
  `feedLivePcm` is synchronous so it could not await the guard anyway.

### Scope of what now holds

Client-side only. There is still no server-side caregiver read API, so there is
nothing server-side for these checks to be enforced against; a holder of a valid
token who does not use this app is unaffected by any of it. Copy may claim a
permission check on this device's surfaces — see Blocker 5 — and must not claim
the limits hold anywhere else.

### The last two export paths — now gated

Both were found while enumerating playback and left open. Neither was reachable
from a caregiver session, because route isolation whitelists `/caregiver` and
`/caregiver/consent` — but that was route isolation doing the work, which is the
arrangement Blocker 1 exists to stop relying on. A `redirect` is a single edit
away from being wrong, and one of these hands every transcript in the archive to
the share sheet.

- `LocalBackupRestoreService.exportBackup`
  (`lib/features/local_backup/local_backup_restore_service.dart`, real path
  `retired_sprawl/lib_features/local_backup/`, reached from
  `privacy_trust_centre_screen.dart` via `local_backup_restore_sheet.dart`)
  writes every journal entry to a JSON file and hands it to the share sheet.
  `LocalBackupBuilder` strips `localAudioPath`, so no audio leaves with it, but
  the transcripts do. The guard sits **ahead of the `isInitialized` early return
  and outside the `try`**, the way `EncryptedCloudBackupService.exportBackup`
  does. That placement is the whole point here and is pinned by a test: with the
  guard moved inside the `try`, the refusal comes back as
  `LocalBackupExportFailure.shareFailed`, which the sheet renders as a transient
  "couldn't share" and invites a retry.
- `SelectedArchiveExport.buildOwnerMarkdown`
  (`lib/features/export/selected_archive_export.dart`, real path
  `retired_sprawl/lib_features/export/`) is the owner-checked entry point for the
  selected-entries markdown.

**Residual, and the reason this is not fully closed.** The share sheet in
`lib/widgets/export/export_selected_sheet.dart` still calls the synchronous
`SelectedArchiveExport.buildMarkdown`, which is a pure formatter and cannot host
the guard — `CaregiverSessionGuard` resolves the persona asynchronously. Closing
the path end to end is a one-line change in that widget:

```dart
final markdown = await const SelectedArchiveExport().buildOwnerMarkdown(
```

`_export` is already `async`, so nothing else in the file moves. Until that
lands, the gate exists and is tested but the production route does not go
through it, and copy must keep naming which export surfaces are checked rather
than claiming exporting is checked in general.

## Blocker 2 — a revoke endpoint and a server-side revocation list — CLOSED

**What was wrong:** revocation was local-only and the server could not be told
about it. `verifyMonitoringConsentToken`
(`packages/shared/lib/caregiver/consent-verification.ts:107`) and
`verifyCoachConsentToken` (`packages/shared/lib/coach/client-consent-verification.ts:122`)
checked policy version, required fields, `expiresAt`, `issuedAt` and the HMAC in
constant time — statelessly, with no revocation lookup. A caregiver holding an
already-issued token off-device kept read access for the remainder of its TTL no
matter what the owner did in the app.

**What now exists:**

- `POST /api/coach/consent/revoke`
  (`apps/api/app/api/coach/consent/revoke/route.ts`), a thin session-gated
  wrapper over `handleConsentRevocation`
  (`packages/shared/lib/server/consent-revoke-handler.ts`). It covers both
  `ConsentGrantKind.caregiverMonitoring` and `ConsentGrantKind.coachClient`; the
  coach branch is not behind the caregiver feature flag and never should be.
- A revocation list in Postgres, table `consent_grants`
  (`packages/shared/lib/server/consent-revocation-store.ts`, DDL in
  `packages/shared/lib/server/db.ts`). It doubles as an issuance registry: the
  issue route writes a row before it hands the token out, so the archive owner
  can revoke later without still holding the token — which matters after a
  reinstall, or when the device was left behind.
- Both server verify wrappers consult the list on **every** call
  (`verifyServerCaregiverConsentToken`, `verifyServerCoachConsentToken`).

**Durability.** Revocation records must outlive the tokens they revoke, so the
table has no TTL, no eviction and no cleanup job, and nothing deletes from it.
It is deliberately *not* in the Redis instance used for rate limiting: that
client is configured with `enableOfflineQueue: false` and degrades to "disabled"
whenever `REDIS_URL` is unset, and a revocation list that can read back as empty
is worse than none — it reports success while quietly reinstating access.
`consent_grants` is listed in `migration-manifest.ts`, so a deployment missing
it fails the migration check rather than discovering it as a consent outage.

**Fail closed.** `isConsentTokenRevoked` throws rather than returning a boolean
when it cannot establish status, and both verify wrappers turn that into
`{ valid: false }`. There is no "assume not revoked" path, and
`scripts/validate-consent-revocation.mjs` fails the build if one appears. An
outage denies access; it never reinstates it.

**Authorization.** Only the archive owner may revoke — `subjectAccountId` for
caregiver grants, `clientAccountId` for coach grants. The caregiver or coach
named in a grant is never authorized, for their own grant or anyone else's, so
they have no lever over the owner's ability to end access. Ownership comes from
the issuance registry; for grants issued before the registry existed, the caller
may instead present the signed token, whose signature is checked without regard
to expiry so a lapsed grant is still revocable. A registry read failure does not
fall back to the presented token.

**Rate limiting.** `/api/coach/consent/revoke` is exempt from the global limiter
(`apps/api/lib/rate-limit/constants.ts`). A failed revoke is worse than an extra
one, and the limiter returns 503 for every limited path when Redis is down — an
unrelated cache outage must not become an inability to revoke.

## Blocker 3 — shorten the stateless TTLs — CLOSED

The default used to be declared twice per role, so shortening one left the other
as a live 30/90-day path. There is now **one declaration per role**, in
`packages/shared/lib/consent/consent-token-ttl.ts`:

| Grant | Was | Now |
|---|---|---|
| Caregiver | 30 days | **7 days** |
| Coach | 90 days | **30 days** |

The server crypto wrappers no longer carry a `DEFAULT_TTL_MS` of their own; they
pass `ttlMs` through and let the single default apply.
`scripts/validate-consent-ttl.mjs` fails the build if a TTL literal reappears in
any consent file outside the canonical module, if either constant is declared
more than once, or if an issue path stops resolving through the shared helper.

Reasoning for the numbers: caregiver access is an active-support arrangement
between people in contact at least weekly, and weekly re-consent puts the
default on the side of access lapsing — which matters most where a writer is not
free to say no. A coaching engagement is arms-length and reviewed monthly, so 30
days is the shortest window that does not interrupt one mid-stream. With
revocation enforced, TTL is a backstop against a leak nobody noticed rather than
the only way to end access.

**Follow-up, not a blocker:** nothing renews a token before it lapses. At 7 days
a legitimate caregiver relationship now needs a re-grant every week, which is
friction the owner pays. A renewal path would be the right way to buy that back;
lengthening the TTL would not.

## Blocker 4 — implement or delete `MultiPartyAccessRole.observer`

`MultiPartyAccessRole` (`lib/features/auth/domain/multi_party_access_grant.dart`)
declares `observer` with a `label`, a `wireValue`, and a `fromWire` case.
Nothing in `lib/` constructs it: `MultiPartyAccessService` emits only
`.caregiver` and `.coach`, and `fromWire` has no callers in `lib/` at all. The
only `observer` instances in the repo are in tests.

A role that exists in the type system and on the wire but has no writer is a
place for a mismatch to hide — a server that starts sending `observer` would be
accepted by `fromWire` and then handled by code that was never written for it.
Either give it a real writer and its own scope semantics, or delete the enum
case, the `fromWire` branch, and the label.

`MultiPartyAccessService` lives at
`lib/features/auth/application/multi_party_access_service.dart` (not
`infrastructure/`, which holds only the two revocation stores) and already
maps `observer` to `null` in both of its scope switches, with a comment saying
it has no consent domain on the server and no production writer. That is the
current containment: the role parses, and then resolves to nothing.

`CaregiverAccessCopy` describes caregiver and coach only. One string still names
the role to users and would become wrong if the enum case is deleted:

- `lib/features/onboarding/ui/onboarding_v1_copy.dart` —
  `OnboardingV1Copy.pillar4Body`, "Caregiver and observer grants require your
  explicit consent." It renders: `trustPillars` carries it into the onboarding
  trust pillars.

`lib/router/v1_route_inventory.dart` also says "Caregiver and observer access",
and that one is **not** user-facing. It is the third positional argument of a
`V1RouteEntry`, whose field is named `capability`; nothing reads it. The only
thing any caller takes from that file is
`V1RouteInventory.v1AllowlistedRouteCount`
(`lib/core/config/v1_production_allowlist.dart`). Fix it when the enum goes,
but do not count it as a disclosure to a user.

## Blocker 5 — re-check the copy against whatever enforcement ships

Two separate things are in play here and must not be conflated: revocation is
now enforced server-side, and the read-only limits are now enforced on this
device and nowhere else.

### The read-only limit strings — rewritten

Blocker 1 landed and the strings that described the limits understated it.
Telling someone a limit is weaker than it is has its own cost, so they were
narrowed rather than left cautious. Each now names the check **and** says where
it runs. The last column is what a reviewer can check, so every row has to be
something they can actually reach — a string on a screen nobody can open is not
evidence, whatever it says:

| Evidence | What it establishes |
|---|---|
| `CaregiverAccessCopy.intentHeading` | "Limits this device enforces" |
| `CaregiverAccessCopy.intentBody` | On this device, exporting, recording and playing back original audio are blocked by a permission check while a caregiver session is active; the check refuses when it cannot tell whose session it is; it runs here rather than on a server |
| `CaregiverAccessCopy` class doc | Names the eight gated surfaces, and names the two export paths and the missing server API that are **not** covered |
| `CaregiverSessionGuard` + `test/security/caregiver_gate_coverage_test.dart`, `caregiver_audio_playback_gate_test.dart`, `caregiver_export_gate_test.dart` | That recording, exporting and playing back the original audio are refused on this device while a caregiver session is active. This is the evidence for that claim; the tests fail first if a gate is removed |
| `CaregiverGrantCopy.cannotCaveat` and its source comment | On this device these limits are checked rather than merely left out of the screens, and the check runs here rather than on a server |

Each string above is reachable: `CaregiverAccessCopy.intentHeading` / `.intentBody`
render in `CaregiverAccessScreen`, which `app_router.dart` builds at
`/caregiver-access`; `CaregiverGrantCopy.cannotCaveat` renders in
`CaregiverDisclosureScreen`, reached from `settings_screen.dart` through
`CaregiverEntryPoint` and `CaregiverGrantFlow.start`. That is the property that
makes them evidence rather than assertion, so it is stated here rather than
left to be rediscovered.

**`CaregiverCopy.dashboardSubtitle` used to be the fourth row and was not
evidence.** It says the right thing, and no user can read it. Its only reader
is `CaregiverDashboardView`, which nothing constructs — and it could not be
reached even if something did, because `RouteCatalog.caregiverHome`
(`/caregiver`) and `RouteCatalog.caregiverConsent` (`/caregiver/consent`) are
declared but registered as routes nowhere in `app_router.dart`. The whole
caregiver-session UI is unrouted; see the note under Blocker 1. A string on an
unreachable surface cannot be checked by using the app, so the claim is now
carried by the guard and the tests that fail first without it.
`tool/check_copy_render_path.py` fails the build if another privacy or trust
constant loses its last render path this way.

`CaregiverGrantCopy.cannotCaveat` was not on the original list. It said the
limits "come from the way the caregiver screens are built, not from a separate
check", which is the same claim in the same words, on the disclosure screen the
owner reads *before* granting access. Its source comment also still described
the alerts-stream exemption that had already been removed.

Do not write "enforced" without the device scope, and do not describe the
per-scope consent choices as guarantees off-device.
`test/security/caregiver_gate_coverage_test.dart` asserts both edges: that none
of these files says the limits are unchecked, and that each still carries "on
this device".

### Still owed

`CaregiverAccessCopy.revokeConfirmBody` and `CaregiverAccessCopy.revokeSuccessSnack`
still say a revoked token "stays valid on the server until its expiry date" and
that revocation takes effect "on this device". Blocker 2 closed, so that reads
as weaker than what happens — but whether the caregiver screen's own revoke
reaches `POST /api/coach/consent/revoke` depends on `MultiPartyAccessService`,
which is being changed separately. Rewrite these together with that path, not
ahead of it. `test/features/settings/ui/caregiver_access_screen_test.dart` still
pins the current wording.

`ConsentAuditCopy.revokedSnack` has already been rewritten to describe the
two-stage revoke, including the queued-retry case. It is the only rewritten
one left: `PrivacySecurityControlCenterCopy.revokeAccessConfirmBody` and its
snack pair were cited here as a second, but the Privacy & Security Control
Center has no revoke control — it links to `/caregiver-access` — so nothing
read them and no user could reach them. They have been removed rather than
counted as a disclosure. Accurate two-stage wording is still owed on
`CaregiverAccessCopy`, which is the set the screen that revokes actually
renders.

Note that `tool/privacy/check_privacy_copy_policy.dart` will not catch a
regression here. Its banned vocabulary covers encryption, medical, and
superlative claims; it has no rule for access-boundary claims. Whether a claim
is *accurate* on this surface is a review responsibility.

`tool/check_copy_render_path.py` catches the adjacent failure, which is the one
that produced the `CaregiverCopy.dashboardSubtitle` row above: a claim that
stays accurate and stops being reachable. It fails the build when a
privacy or trust constant loses its last render path — when its only readers
are other copy, tests, or a widget class nothing constructs. It starts from a
baseline of pre-existing cases and blocks only new ones, so it says nothing
about the debt already there.

## Discoverability gate (in force now)

The ship checklist in the governance doc requires "no settings/account nav entry
without flag". Both entries that had appeared are now gated on
`V1CapabilityRegistry.caregiverMonitoring`, which delegates to
`CaregiverFeatureFlags.isCaregiverModeEnabled`:

- `lib/screens/settings_screen.dart` — the `settings_caregiver_access_tile` row
- `lib/widgets/settings/privacy_security_trust_section.dart` — the caregiver
  guarantee block and the `Manage caregiver access` link

`/caregiver-access` itself stays registered in `lib/router/app_router.dart`, and
`/consent-audit` stays ungated. That is deliberate, and more so now that revoking
does something: a grant issued while the flag was on keeps verifying until it is
revoked or expires, so the surfaces that list and revoke it must survive the flag
going off — otherwise the flag becomes a way to strand a live grant with no way
to end it. `/consent-audit` also covers `ConsentGrantKind.coachClient`, and
nothing in the coach path reads `CaregiverFeatureFlags` — coach grants live 30
days and are issued independently of caregiver monitoring. Do not gate
`/consent-audit` on the caregiver flag, and
do not fold it into `CaregiverAccessScreen`; link to it from there instead, which
is what `caregiver_access_consent_audit_link` does.

## Consolidation step (applied)

`lib/ui/screens/settings/privacy_security_screen.dart` used to mount
`CaregiverConsentManagerWidget` inside its pillar-4 section, which made it a
third revoke surface and the only caregiver entry point that was **not**
flag-gated. That section and its `PrivacyPillarExpansionSection` are gone,
replaced by a `privacy_security_caregiver_access_link` `ListTile` to
`/caregiver-access` wrapped in `if (V1CapabilityRegistry.caregiverMonitoring)`.
`CaregiverConsentManagerWidget` had no other referent and was deleted in the
same change; `caregiver_token_revoked` is emitted from
`CaregiverAccessGrantList`, so the funnel survived the deletion.
