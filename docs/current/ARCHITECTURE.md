# ArchiveMe V1 architecture

Machine-readable authority:
`config/product/archive_me_v1_release_contract.json` and
`config/release/archive_me_v1_backend_allowlist.json`.

## Shipping boundary

The Flutter application in `apps/voicememory_mobile` is the shipping client.
The retained Next.js application is an API-only backend artifact. Consumer web
pages and the Capacitor shell are outside the release graph; the residual
Capacitor project under `android/` is neutralised by exclusion and is not
buildable. Flutter owns the Record, Archive, Changes, and Account experience.

## Domain flow

`RecordingService` captures audio. Focused recording application services own
permission, protected temporary audio, vault persistence, transcription,
saving, transcript editing, and post-save selection. The Record state
controller is a presentation adapter and must not acquire ranking or product
policy.

`SavedMoment` (`JournalEntry` is the migration alias) is the single persisted
journal aggregate. Transcript edits create edit history and invalidate stale
evidence offsets.

`ExplainableConclusion` is the only interpretation contract.
`ExplainableConclusionValidator` is the mandatory render boundary.
`AuditableConclusionTrustPolicy` is the single deterministic ranking and
feedback-suppression policy. `ChangeHistoryItem` is the chronological Changes
projection; it references validated source evidence rather than copying an
independent claim format. Its status vocabulary is first observed, repeated,
changed, weakened, strengthened, unresolved, and corrected. Directional status
requires explicit evidence of changed frequency, intensity, certainty,
duration, behavioural pull, or consequence.

## Processing boundary

On-device transcription uses `WhisperOnDeviceTranscriptionEngine` over a
short-lived decrypted vault lease and sends no recording content. Two optional
capabilities can leave the device through the ArchiveMe backend:

| Client call site | Route | Provider used by the route |
| --- | --- | --- |
| `apps/voicememory_mobile/lib/api/voice_capture_api_client.dart:70` | `/api/transcribe` | `app/api/transcribe/route.ts:104` — `whisper-1` |
| `apps/voicememory_mobile/lib/api/voice_capture_api_client.dart:145` | `/api/analyze` | `app/api/analyze/route.ts:237` — `gpt-4o-mini` |

Online transcription is gated by an explicit current choice or archive-scoped
private default and a versioned just-in-time transcription disclosure
(`apps/voicememory_mobile/lib/features/remote_transcription/remote_transcription_disclosure.dart`)
and by capture attestation via `/api/capture/attest`. Interpretation has a
separate choice and separate disclosure acceptance; transcription acceptance is
never sufficient. Both typed and voice originals are durable before optional
interpretation, and declining AI remains a successful archive operation.

## Local storage boundary

- Journal and other private JSON blobs are encrypted at rest with AES-256-GCM
  through `EncryptedJsonFileStore`
  (`apps/voicememory_mobile/lib/storage/encrypted_json_file_store.dart:21`).
- The file key lives only in platform secure storage via
  `SecurePrivateDataEncryptionKeyStore`
  (`apps/voicememory_mobile/lib/storage/private_data_encryption_key_store.dart:22`),
  optionally behind the biometric vault.
- Preferences go through `MobilePrefsStore`, which is backed by
  `SecureStorageService` in production and migrates any legacy plaintext file
  into secure storage once, then deletes it
  (`apps/voicememory_mobile/lib/storage/mobile_prefs_store.dart:8`).
  `SecureStorageService` uses Android `encryptedSharedPreferences` and iOS
  Keychain with `first_unlock` accessibility
  (`apps/voicememory_mobile/lib/storage/secure_storage.dart:9`), and refuses keys
  that look like secrets.
- Archives are physically partitioned. `ArchiveScopePaths`
  (`apps/voicememory_mobile/lib/features/archive_ownership/archive_scope_paths.dart:8`)
  is the only mapping from archive identity to file locations, and `JournalStore`
  requires an explicit non-empty `ownerArchiveId`
  (`apps/voicememory_mobile/lib/storage/journal_store.dart:38`).

## Sync boundary

The canonical sync route is `/api/sync/manifest`, `/api/sync/pull`, and
`/api/sync/push`. `SavedMomentSyncCipher`
(`apps/voicememory_mobile/lib/features/journal/sync/saved_moment_sync.dart:118`)
encrypts each record client-side with AES-256-GCM, binding
`ownerArchiveId` and `entryId` into the AAD, and `/api/sync/push`
(`app/api/sync/push/route.ts:40`) accepts encrypted envelopes only and rejects
plaintext archive fields.

The sync key is generated on the device and held in secure storage by
`SavedMomentSyncKeyStore`
(`apps/voicememory_mobile/lib/features/journal/sync/saved_moment_sync_key_store.dart:10`).
The server never receives it. There is no key escrow and no user-controlled
recovery-key exchange, so a second device cannot decrypt this device's cloud
copy. This is client-side payload encryption with a device-held key; it is not
end-to-end encryption in the multi-device sense, and it offers no key recovery.
Loss of that key makes the encrypted cloud copy unrecoverable.
See `DATA_FLOW_AND_PRIVACY.md`.

A separate legacy server journal store still exists behind `/api/journal` and
`/api/journal/[id]`, classified `MIGRATION_ONLY` in
`config/release/archive_me_v1_backend_allowlist.json` and not called by the
shipping client. It is retained only so pre-encryption data stays exportable.

## Presentation invariants

- Post-save order is Saved → editable Transcript → zero or one interpretation
  → inline evidence → correction controls → one next action.
- The first entry cannot render pattern or change.
- Then/Now comparisons require related, distinct entries, different quotes, and
  chronological source dates.
- `ExplainableConclusionCard` is the shared receipt and correction component.
- Confidence reaches the reader only as a band label, never as a number.
- Record and Changes expose no graph, analyst, blind-spot, contradiction, or
  experimental navigation.

## Access and privacy boundaries

`AccessPolicyEngine` consumes the generated monetization policy. RevenueCat is
an entitlement input, not product policy. Existing results and user-owned
content are permanently readable; first observation and first comparison are
free proof; new ongoing generation follows Pro and meter decisions.

Encrypted storage is authoritative for audio. Plaintext temporary audio uses
opaque names in private no-backup storage, is bounded to 24 hours from original
creation, and is removed after vault persistence. Encrypted playback holds one
bounded decrypted lease and deletes it on stop, completion, error, account
change, or disposal. `FocusedReturnAnalytics` is the typed metadata-only
boundary for post-save and Changes telemetry.

Processing preferences are archive-scoped, device-private, and revocable.
Account switching must not carry one archive's choices into another. Export
hands readable user content to the chosen destination, so local encryption does
not follow the file after handoff. Provider retention is outside the guarantees
enforced by this repository, and local/account deletion is not evidence of
provider-side deletion.

## Dependency composition

`V1Composition` owns Core, Account, Recording, Archive, Changes, Privacy,
Monetization, Analytics, and Sync modules. `AppServices` is a composition
facade; recording services are lazy and account-scoped state is reset on
account change. Dormant or excluded capabilities cannot register or initialize
services. The allowed startup services are listed in
`config/product/archive_me_v1_contract.json`.

## Backend surface

Every addressable route must appear in
`config/release/archive_me_v1_backend_allowlist.json`, enforced by
`npm run check:backend-allowlist`. A route file is not the only way to become
addressable, so the same guard also fails if `server.entry.ts` re-attaches a
WebSocket upgrade. The live-audio and cloud-relay upgrades are not reachable:
their handlers were removed from `app/api` and their upgrade calls are no
longer attached, under `next start` or the custom server.
`scripts/build-server.mjs` rejects a bundle that still contains those symbols.

`config/release/archive_me_v1_backend_allowlist.json` also records that the
shipping client POSTs to `/api/billing/restore` while no handler exists. That
gap is unresolved here.

## Verification

Architecture changes must keep `flutter analyze` clean and cover validator,
trust policy, post-save ordering, transcript invalidation, early comparison,
correction, Changes chronology, navigation exclusions, accessibility, and the
four-destination shell. Documentation changes must keep
`npm run test:docs-drift` green.
