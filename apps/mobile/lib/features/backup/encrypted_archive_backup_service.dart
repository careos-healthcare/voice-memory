import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_codec.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_destination.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';

/// Exports and restores the on-device archive. Does nothing while
/// [V1CapabilityRegistry.encryptedBackup] is false.
class EncryptedArchiveBackupService {
  EncryptedArchiveBackupService({
    required this.databaseFile,
    required this.audioDirectory,
    required this.destination,
    this.photosDirectory,
    this.secureStorage,
    this.kdfProfile = ArchiveBackupKdfProfile.production,
    this.weeklyEnabled = false,
  });

  static const recoveryPhraseKey = 'archive_recovery_phrase';
  static const weeklyPrefKey = 'encrypted_archive_weekly_enabled';

  final File databaseFile;
  final Directory audioDirectory;
  final Directory? photosDirectory;
  final EncryptedArchiveBackupDestination destination;
  final SecureStorageService? secureStorage;
  final ArchiveBackupKdfProfile kdfProfile;
  final bool weeklyEnabled;

  Future<void> backupNow(String passphrase) async {
    if (!V1CapabilityRegistry.encryptedBackup) return;
    final sealed = await EncryptedArchiveBackupCodec.seal(
      databaseFile: databaseFile,
      audioDirectory: audioDirectory,
      photosDirectory: photosDirectory,
      passphrase: passphrase,
      profile: kdfProfile,
    );
    await destination.write(sealed);
    await secureStorage?.write(recoveryPhraseKey, passphrase.trim());
  }

  Future<void> restoreFromBackup(String passphrase) async {
    if (!V1CapabilityRegistry.encryptedBackup) return;
    final sealed = await destination.read();
    await EncryptedArchiveBackupCodec.restore(
      sealed: sealed,
      passphrase: passphrase,
      databaseFile: databaseFile,
      audioDirectory: audioDirectory,
      photosDirectory: photosDirectory,
    );
  }

  /// Weekly WorkManager entry. Skips when the flag or the weekly choice is off.
  Future<bool> runWeeklyIfEnabled() async {
    if (!V1CapabilityRegistry.encryptedBackup || !weeklyEnabled) return true;
    final phrase = await secureStorage?.read(recoveryPhraseKey);
    if (phrase == null || phrase.length < 8) return true;
    await backupNow(phrase);
    return true;
  }
}

/// Remembers a user-chosen Android file for the next weekly run.
class EncryptedArchiveBackupLocation {
  const EncryptedArchiveBackupLocation(this.path);

  final String path;

  File get file => File(path);
}
