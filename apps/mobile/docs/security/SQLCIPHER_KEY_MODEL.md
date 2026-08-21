# SQLCipher key model and defensible privacy copy

This document describes how ArchiveMe encrypts the local journal database,
how encryption keys are generated and stored, and which marketing claims
are supportable today.

## Summary

| Claim | Supportable now? |
| --- | --- |
| Journal encrypted at rest on this device (SQLCipher) | Yes |
| Encryption keys stored in OS secure storage, not in prefs or the DB file | Yes |
| Face ID / Touch ID gate before unlocking the in-memory key | Yes (when device biometrics available) |
| Keys never leave this device under normal operation | Yes (local-only key provisioning) |
| Zero-knowledge (service operator cannot decrypt user data) | **Not yet** — see below |

## Key generation

On first boot, [`SecureSqliteEncryptionKeyStore.ensureEncryptionKey()`](../lib/security/sqlite/sqlite_encryption_key_store.dart)
checks OS secure storage for an existing key. If none exists, it generates a
fresh **256-bit random key** via
[`SqliteDatabaseEncryptionKey.generate()`](../lib/storage/sqlite/sqlite_database_encryption_key.dart)
(`Random.secure()`, 32 bytes) and persists the base64-encoded raw key.

The key is **not derived from a user-chosen password** and is **not**
reconstructable from biometrics alone.

## Key storage

- **v2 (current):** raw 256-bit key, base64-encoded, in
  [`SecureStorageService`](../lib/storage/secure_storage.dart) under
  `sqlite_encryption_key_v2` (optionally namespaced per account alias).
- **v1 (legacy):** passphrase alias `sqlite_encryption_passphrase_v1`; read
  path migrates forward when encountered.

The SQLCipher password string passed to `openDatabase` is derived from this
stored material. The raw key is **never written into SharedPreferences, the
encrypted `.db` file, or application logs**.

## Unlock and lock lifecycle

[`SecureSqliteLockService`](../lib/security/sqlite/secure_sqlite_lock_service.dart):

1. **Bootstrap:** loads or creates the persisted key into an in-memory session
   (`SecureSqliteSession`).
2. **Biometric gate:** `unlockWithBiometric()` requires Face ID / Touch ID
   (via `LocalAuthBiometricAuthenticator`) before restoring the in-memory
   passphrase after a lock.
3. **Lock:** wipes the in-memory passphrase and closes the DB handle on app
   background / explicit lock.

Biometrics **gate access to the already-provisioned device key**; they do not
derive the encryption key.

## Recovery model

- **Same device, reinstall without backup:** key in secure storage may be
  cleared by the OS → local journal becomes unreadable (expected for
  device-bound encryption).
- **No cloud key escrow:** ArchiveMe does not upload the SQLCipher key.
- **Not user-memorized:** there is no user passphrase to type; recovery is
  device-bound, not password-based.

## Defensible user-facing copy

**Use:**

- "Your journal file on this device is encrypted."
- "Opening ArchiveMe can require Face ID or Touch ID."
- "Encryption keys stay in your device's secure storage."

**Avoid until the key model changes:**

- "Zero-knowledge" — strictly, that implies the operator never holds key
  material *and* that keys are derived only from user secrets the service
  never sees. Our model uses a **device-generated key in OS secure storage**,
  not a user-derived secret never persisted anywhere.
- "Military-grade", "100% secure", "unhackable", or absolute "never leaves
  your device" without the on-device-processing caveat.

## Related code

- `lib/security/sqlite/secure_sqlite_lock_service.dart`
- `lib/security/sqlite/sqlite_encryption_key_store.dart`
- `lib/storage/sqlite/sqlite_database_encryption_key.dart`
- Settings trust copy: `lib/features/privacy/privacy_security_trust_copy.dart`
