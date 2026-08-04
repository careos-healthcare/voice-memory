# ArchiveMe V1 migrations

Migration readers are one-way and preserve installed-user access. They do not
reactivate removed product systems.

## Client migrations

- Legacy `vm_rec_*` plaintext audio keeps its original creation timestamp.
  Empty, corrupt, or older-than-24-hour files are deleted. Valid files are
  renamed into protected no-backup storage, assigned to the known local archive
  when available, otherwise quarantined, and never uploaded automatically.
  (`apps/voicememory_mobile/lib/services/privacy/sensitive_temporary_audio_store.dart`)
- Plaintext journal JSON is migrated once into the encrypted journal envelope by
  `EncryptedJsonFileStore.migrateFromPlaintextFile`
  (`apps/voicememory_mobile/lib/storage/encrypted_json_file_store.dart:110`),
  which refuses to overwrite an existing encrypted file and deletes the plaintext
  source once the encrypted copy is written.
- The legacy plaintext preferences file is read once and migrated into platform
  secure storage, then deleted
  (`apps/voicememory_mobile/lib/storage/mobile_prefs_store.dart:41`). The
  plaintext file is retained in the code only as that one-time migration source
  and as an explicitly selected test backend.
- Historical saved-moment schema fields are read by
  `SavedMomentLegacyAdapter`
  (`apps/voicememory_mobile/lib/features/journal/migration/saved_moment_legacy_adapter.dart`);
  writes use only the current schema version.
- A pre-partition archive is treated as `legacyUnclaimed` and keeps its original
  journal path
  (`apps/voicememory_mobile/lib/features/archive_ownership/archive_scope_paths.dart:26`)
  until the user makes an explicit ownership decision. Nothing is claimed into an
  account automatically.
- Historical subscription identifiers are accepted only through the explicit
  entitlement migration and the `legacyGrandfatheredProductIds` allowlist in
  `config/monetization/archive_me_entitlement_matrix.json`.
- Sync tombstones and mutation metadata remain readable across the supported
  schema versions. `SavedMomentSyncCipher` rejects an envelope whose
  `ownerArchiveId` does not match the expected archive
  (`apps/voicememory_mobile/lib/features/journal/sync/saved_moment_sync.dart:144`).

## Backend migrations

SQL migrations live in `docs/sql/` and are applied in filename order. They are
written to be idempotent. `npm run validate:migrations` is the gate.

The legacy server journal store behind `/api/journal` is classified
`MIGRATION_ONLY` in `config/release/archive_me_v1_backend_allowlist.json`. It is
retained so pre-encryption rows stay reachable for `/api/journal/export`; the
shipping client does not write to it.

## Failure rule

A migration failure must leave the authoritative old copy available for retry;
it must not fabricate a successful marker or create two recoverable plaintext
audio copies.

## Not verified here

No migration has been executed against a production database or a real user
device as part of writing this document.
