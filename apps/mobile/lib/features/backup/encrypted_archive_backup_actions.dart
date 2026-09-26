import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_codec.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_destination.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_service.dart';
import 'package:archiveme_mobile/features/backup/encrypted_archive_backup_workmanager.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/audio/local_audio_storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Settings control for a manual backup. Hidden while the flag is off.
class EncryptedArchiveBackupSettingsTile extends StatelessWidget {
  const EncryptedArchiveBackupSettingsTile({
    super.key,
    this.onBackup,
    this.weeklyEnabled = false,
    this.onWeeklyChanged,
  });

  final Future<void> Function(String passphrase)? onBackup;
  final bool weeklyEnabled;
  final ValueChanged<bool>? onWeeklyChanged;

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.encryptedBackup) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const Key('settings_backup_now'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Back up now'),
          subtitle: const Text(
            'Write a sealed copy of this archive to iCloud or a drive file.',
          ),
          onTap: () => _askPassphrase(context),
        ),
        SwitchListTile(
          key: const Key('settings_backup_weekly'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Weekly automatic backup'),
          value: weeklyEnabled,
          onChanged: (value) async {
            onWeeklyChanged?.call(value);
            if (!value || !V1CapabilityRegistry.encryptedBackup) return;
            await EncryptedArchiveBackupScheduler.registerWeekly(
              runner: () async {
                final phrase = await AppServices.instance.secureStorage.read(
                  EncryptedArchiveBackupService.recoveryPhraseKey,
                );
                if (phrase == null || phrase.length < 8) return true;
                if (!kIsWeb && Platform.isAndroid) {
                  final path = await AppServices.instance.prefs.readString(
                    _androidBackupPathKey,
                  );
                  if (path == null || path.isEmpty) return true;
                  final service = EncryptedArchiveBackupService(
                    databaseFile: File(
                      AppServices.instance.activeSqliteFilePath,
                    ),
                    audioDirectory: Directory(
                      '${AppServices.instance.documentsBasePath}/'
                      '${LocalAudioStorageService.pendingAudioDirectoryName}',
                    ),
                    photosDirectory: _photosDirectory(),
                    destination: FileEncryptedArchiveBackupDestination(
                      File(path),
                    ),
                    secureStorage: AppServices.instance.secureStorage,
                    weeklyEnabled: true,
                  );
                  return service.runWeeklyIfEnabled();
                }
                await backupArchiveNow(phrase);
                return true;
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _askPassphrase(BuildContext context) async {
    final controller = TextEditingController();
    final phrase = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Back up now'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Recovery passphrase',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Back up now'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (phrase == null || phrase.trim().length < 8) return;
    if (onBackup != null) {
      await onBackup!(phrase.trim());
      return;
    }
    await backupArchiveNow(phrase.trim());
  }
}

/// Seals the live archive and writes ciphertext to iCloud or a picked file.
Future<void> backupArchiveNow(String passphrase) async {
  if (!V1CapabilityRegistry.encryptedBackup || !AppServices.isInitialized) {
    return;
  }
  final database = File(AppServices.instance.activeSqliteFilePath);
  final audio = Directory(
    '${AppServices.instance.documentsBasePath}/'
    '${LocalAudioStorageService.pendingAudioDirectoryName}',
  );
  if (!kIsWeb && Platform.isIOS) {
    final service = EncryptedArchiveBackupService(
      databaseFile: database,
      audioDirectory: audio,
      photosDirectory: _photosDirectory(),
      destination: ICloudEncryptedArchiveBackupDestination(),
      secureStorage: AppServices.instance.secureStorage,
    );
    await service.backupNow(passphrase);
    return;
  }
  final sealed = await EncryptedArchiveBackupCodec.seal(
    databaseFile: database,
    audioDirectory: audio,
    photosDirectory: _photosDirectory(),
    passphrase: passphrase,
  );
  final savedPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Back up now',
    fileName: 'thoughtprint-archive.vmab',
    bytes: sealed,
  );
  if (savedPath != null && savedPath.isNotEmpty) {
    await AppServices.instance.prefs.writeString(
      _androidBackupPathKey,
      savedPath,
    );
  }
  await AppServices.instance.secureStorage.write(
    EncryptedArchiveBackupService.recoveryPhraseKey,
    passphrase.trim(),
  );
}

const _androidBackupPathKey = 'encrypted_archive_backup_android_path';

/// Opens a sealed archive from iCloud or a picked file onto the live database.
Future<void> restoreArchive(String passphrase) async {
  if (!V1CapabilityRegistry.encryptedBackup || !AppServices.isInitialized) {
    return;
  }
  final database = File(AppServices.instance.activeSqliteFilePath);
  final audio = Directory(
    '${AppServices.instance.documentsBasePath}/'
    '${LocalAudioStorageService.pendingAudioDirectoryName}',
  );
  if (!kIsWeb && Platform.isIOS) {
    final service = EncryptedArchiveBackupService(
      databaseFile: database,
      audioDirectory: audio,
      photosDirectory: _photosDirectory(),
      destination: ICloudEncryptedArchiveBackupDestination(),
    );
    await service.restoreFromBackup(passphrase);
    return;
  }
  final picked = await FilePicker.platform.pickFiles(withData: true);
  final bytes = picked?.files.single.bytes;
  if (bytes == null) return;
  await EncryptedArchiveBackupCodec.restore(
    sealed: bytes,
    passphrase: passphrase,
    databaseFile: database,
    audioDirectory: audio,
    photosDirectory: _photosDirectory(),
  );
}

Directory _photosDirectory() {
  return Directory('${AppServices.instance.documentsBasePath}/journal-images');
}

/// Onboarding control. Hidden while the flag is off.
class RestoreFromBackupButton extends StatelessWidget {
  const RestoreFromBackupButton({super.key, this.onRestore});

  final Future<void> Function(String passphrase)? onRestore;

  @override
  Widget build(BuildContext context) {
    if (!V1CapabilityRegistry.encryptedBackup) {
      return const SizedBox.shrink();
    }
    return TextButton(
      key: const Key('onboarding_restore_from_backup'),
      onPressed: () => _ask(context),
      child: const Text('Restore from backup'),
    );
  }

  Future<void> _ask(BuildContext context) async {
    final controller = TextEditingController();
    final phrase = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore from backup'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Recovery passphrase',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Restore from backup'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (phrase == null || phrase.trim().length < 8) return;
    if (onRestore != null) {
      await onRestore!(phrase.trim());
      return;
    }
    await restoreArchive(phrase.trim());
  }
}
