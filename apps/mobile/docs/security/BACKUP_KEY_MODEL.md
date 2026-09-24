# Backup key model

Thoughtprint can write one sealed archive of the on-device SQLCipher database
and audio files. The server never receives the recovery passphrase, the
derived key, or the archive plaintext.

`V1CapabilityRegistry.encryptedBackup` is false until this flow is reviewed.
While it is false, backup and restore do not run.

## What is sealed

`EncryptedArchiveBackupCodec` packs `archive.db` and the files in the audio
directory into a zip, then encrypts that zip with AES-256-GCM. The file that
iCloud Drive or the Android Storage Access Framework receives is the sealed
bytes only.

## Key derivation

The user chooses a recovery passphrase. The app derives a 256-bit key with
Argon2id from the `cryptography` package:

| Parameter | Production |
| --- | --- |
| Memory | 19456 KiB |
| Iterations | 2 |
| Parallelism | 1 |
| Salt | 16 random bytes, stored in the archive header |

The salt and Argon2id cost travel with the ciphertext so a new phone can
open the same file. They are not secret. The passphrase is not written into
the archive.

After a manual backup, the passphrase may be kept in the device keystore
(`SecureStorageService`, key `archive_recovery_phrase`) so a weekly
WorkManager task can seal another archive without asking again. That copy
stays on the device. It is not uploaded.

## Where the sealed file goes

- iOS: iCloud Drive container `iCloud.com.voicememory.mobile`, path
  `backups/thoughtprint-archive.vmab`, through the existing `icloud_storage`
  plugin. The plugin is given the sealed file path.
- Android: a file the user picks with the Storage Access Framework. That
  location can be a Google Drive folder. The app does not call a Google
  account API and does not send the passphrase anywhere.

## Restore

Onboarding shows "Restore from backup" only when the flag is on. Restore
decrypts the whole archive in memory first. A wrong passphrase raises
`WRONG_PASSPHRASE`. A file that is not a sealed archive raises
`CORRUPT_ARCHIVE`. Neither path replaces the existing database.

## What a server can see

Nothing from this flow. There is no backup upload endpoint. iCloud and
Google Drive, when the user picks them, store ciphertext the app already
sealed.
