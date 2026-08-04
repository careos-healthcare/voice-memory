# ArchiveMe V1 data flow and privacy

The machine-readable authority is
`config/privacy/archive_me_data_flow.json` (policy version `2026-08-01`). This
document explains that manifest; it is not a second policy.

## Summary of what is true today

- The local journal is **encrypted at rest** with AES-256-GCM.
- The audio vault is **encrypted at rest** with AES-GCM.
- Preferences and keys live in **platform secure storage**, never in plaintext
  preferences.
- Sync payloads are **encrypted client-side** before upload, and the server
  stores ciphertext.
- This is **not end-to-end encryption**. The sync key is device-held. Users may
  opt into recovery by creating a separate code on-device; the server receives
  only an authenticated encrypted wrapping of that key.
- Transcription can use the on-device Whisper engine when its local model is
  available. Choosing online transcription uploads audio. Interpretation is
  remote and uploads saved text plus eligible prior evidence.
- ArchiveMe is not local-only: online transcription, interpretation, sync,
  analytics, account, and billing flows cross the device boundary as described
  below.
- Transcription permission does not authorize interpretation. Each remote
  purpose has its own current disclosure acceptance, and the original is saved
  before optional interpretation.

## Flow by flow

Each row below corresponds to a flow id in
`config/privacy/archive_me_data_flow.json`.

| Flow | What leaves the app | Encryption state |
| --- | --- | --- |
| `typed_entry` | nothing | `encrypted_at_rest` in the app-private journal |
| `temporary_plaintext_audio` | nothing | plaintext during capture and recovery only, app-private, excluded from backup, bounded to 24 hours |
| `encrypted_audio_vault` | nothing | `aes_gcm_encrypted_at_rest` |
| `remote_transcription` | the recording, only after the online choice and current transcription disclosure | HTTPS in transit to the configured transcription provider |
| `validated_analysis` | transcript plus prior evidence | HTTPS in transit; the resulting conclusion and citations are stored encrypted locally |
| `encrypted_sync` | ciphertext only | client-side AES-256-GCM payload encryption |
| `analytics` | allowlisted structural metadata only | HTTPS in transit |
| `billing` | store transaction metadata | provider transport and platform storage |
| `export` | whatever the user chose to export | format and destination dependent |
| `account_deletion` | a deletion request | not applicable |

## Local storage

Original typed text and transcripts are encrypted at rest in the local journal
via `EncryptedJsonFileStore`
(`apps/voicememory_mobile/lib/storage/encrypted_json_file_store.dart:21`). The
AES key is generated on device and stored only in platform secure storage by
`SecurePrivateDataEncryptionKeyStore`
(`apps/voicememory_mobile/lib/storage/private_data_encryption_key_store.dart:22`),
optionally gated behind the biometric vault.

Preferences are not stored in a plaintext file in production. `MobilePrefsStore`
(`apps/voicememory_mobile/lib/storage/mobile_prefs_store.dart:8`) is backed by
`SecureStorageService`; on first open with secure storage present it validates
and migrates any legacy plaintext file into secure storage and then deletes it.
`SecureStorageService`
(`apps/voicememory_mobile/lib/storage/secure_storage.dart:9`) uses Android
`encryptedSharedPreferences` and the iOS Keychain with `first_unlock`
accessibility, and rejects key names that look like secrets.

Recorded audio enters `SensitiveTemporaryAudioStore`, remains plaintext for no
more than 24 hours, is excluded from backup, and is deleted after successful
vault encryption. Operating-system force termination cannot guarantee an
immediate callback; startup cleanup enforces the bound on the next launch.

## Local and remote processing

On-device transcription uses the local Whisper engine over a short-lived
decrypted audio lease. It does not upload the recording. Model preparation may
download model assets while online; that download is not a recording upload.

Online transcription occurs only after the user chooses it (for the current
recording or as an archive-scoped private default) and the versioned
transcription disclosure is accepted
(`apps/voicememory_mobile/lib/features/remote_transcription/remote_transcription_disclosure.dart`)
and after capture attestation. The recording is uploaded to `/api/transcribe`
from `apps/voicememory_mobile/lib/api/voice_capture_api_client.dart:70`, and
that route calls the configured speech provider
(`app/api/transcribe/route.ts:104` — `whisper-1`).

Validated interpretation is a separate choice and separately accepted
disclosure. Accepting online transcription never authorizes interpretation.
The transcript and prior evidence are sent to `/api/analyze` from
`apps/voicememory_mobile/lib/api/voice_capture_api_client.dart:145`, and that
route calls the configured analysis provider
(`app/api/analyze/route.ts:237` — `gpt-4o-mini`). The result must use exact
saved evidence at the render boundary or it is not shown.

Declining or dismissing either AI choice leaves the original archived. A saved
moment can request interpretation later if it is then eligible. Stored choices
and disclosure acceptances are revocable. Before draining encrypted retry work,
the queue re-reads the active archive's current choice and purpose-specific
disclosure. Revoked work is dropped without deleting the saved original.

## Sync — client-side encrypted, not end-to-end encrypted

`SavedMomentSyncCipher`
(`apps/voicememory_mobile/lib/features/journal/sync/saved_moment_sync.dart:118`)
encrypts each record with AES-256-GCM before upload and binds the owning archive
id and entry id into the additional authenticated data, so a ciphertext cannot be
replayed into another archive. `/api/sync/push`
(`app/api/sync/push/route.ts:40`) accepts encrypted envelopes only and rejects
plaintext archive fields.

The key is generated with `Random.secure()` on the device and stored per archive
in secure storage by `SavedMomentSyncKeyStore`
(`apps/voicememory_mobile/lib/features/journal/sync/saved_moment_sync_key_store.dart:10`).
The server never receives it in plaintext.

Being honest about the limits of that design:

- There is no operator-held key escrow, so the operator cannot read synced
  content.
- Recovery is opt-in. The client generates a 256-bit recovery secret, derives a
  wrapping key with PBKDF2-HMAC-SHA256 (310,000 iterations), and wraps the
  existing random 256-bit sync key with AES-256-GCM. Account, archive, key
  epoch, envelope revision, algorithms, and timestamps are authenticated
  metadata. The recovery secret is shown once and is never sent, logged,
  analyzed, crash-reported, stored by the app, or automatically exported.
- `/api/sync/recovery` stores only the versioned encrypted envelope, scoped to
  the authenticated account. It rate-limits requests, rejects stale or
  conflicting revisions, and deletes the envelope with account deletion.
- A new device can unwrap only while signed into the bound account and with the
  complete recovery code; after authentication it adopts the archive id bound
  into the envelope. Wrong, truncated, modified,
  cross-account, cross-archive, wrong-schema, wrong-epoch, and stale envelopes
  fail closed. Losing both every device-held key and the recovery code still
  makes the encrypted cloud copy unrecoverable.
- Because there is no cross-device key agreement and no verified recipient
identity, this remains not end-to-end encryption. Calling it end-to-end
encrypted would overstate it. Describe it as client-side encrypted sync with a
device-held key and optional user-controlled recovery wrapping.
- A legacy plaintext server journal store still exists behind `/api/journal`,
  classified `MIGRATION_ONLY` in
  `config/release/archive_me_v1_backend_allowlist.json`. The shipping client does
  not write to it, but data written by earlier clients may still sit there in
  plaintext and is retained so it stays exportable.

## Analytics

Analytics is not a journal flow. Its provider boundary accepts only catalogued
event IDs from `config/product/archive_me_v1_analytics_events.json` and fixed
metadata tokens, flags, and bands. Journal text, transcript, quotes,
conclusions, corrections, prompts, topics, identifiers, email, tokens, and
billing customer IDs are prohibited. Confidence reaches analytics as a band
name, never as a number.

The catalog includes structural save, transcription, interpretation, retry,
vault, sync/recovery, commerce, deletion, and export lifecycle events. Typed
facades accept only enums and pre-bucketed counts; the payload is validated
when built and again immediately before provider dispatch. A crash-reporting
adapter accepts only app/build/platform/channel plus fixed category and timing
bands. No crash provider is configured in this release, so its production
status is disabled and raw errors, stack details, breadcrumbs, content, paths,
and identifiers cannot be sent.

## Billing, export, deletion

Billing receives store identifiers and entitlement state through the canonical
RevenueCat adapter. Export is an explicit user action. Readable export contains
text, metadata, evidence, corrections, Changes, weekly-review history, and audio
references but no audio bytes. Full export creates one archive containing that
readable document, machine-readable JSON, available original audio, and a
versioned checksummed manifest. Audio is decrypted one file at a time into an
opaque app-private temporary directory. Temporary material is cleaned after
handoff, cancellation, or failure. Exported plaintext and audio are controlled
by the destination after handoff. Recovery codes, sync keys, credentials,
tokens, absolute device paths, and provider identifiers are explicitly
excluded.

Only the structural `export_completed` event may describe an export, using
bounded format and result tokens. Exported content, filenames, paths, archive
identifiers, checksums, entry identifiers, and errors remain prohibited
analytics data.

Account switching closes or pauses account-scoped work and opens the separately
partitioned archive; processing preferences and disclosure acceptances are
keyed by archive and are not inherited by the next account. Account deletion
clears the server account, local journal and vault, derived conclusions and
corrections, queued work, credentials, and analytics identity as listed in the
manifest, including any server recovery envelope, and is idempotent. It cannot
recover a lost sync key or retract data already exported to another app.

## Not verified here

`config/privacy/archive_me_data_flow.json` links the export flow to round-trip
and analytics-boundary tests. It still lists no automated end-to-end test for
the `account_deletion` flow. Provider-side retention and deletion for
transcription and analysis are contractual matters that cannot be verified from
this repository. Local/account deletion must not be described as proof that a
provider has deleted its copy.
