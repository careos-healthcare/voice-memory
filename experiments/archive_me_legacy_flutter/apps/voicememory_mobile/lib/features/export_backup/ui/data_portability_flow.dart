import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/app_services.dart';
import '../../../storage/app_storage_paths.dart';
import '../../../storage/private_data_encryption_key_store.dart';
import '../markdown_export_service.dart';
import '../vault_backup_models.dart';
import '../vault_backup_service.dart';
import '../vault_production_adapters.dart';
import '../vault_restore_service.dart';
import 'data_portability_sheet.dart';

abstract final class DataPortabilityFlow {
  static const _lastBackupKey = 'data_portability_last_backup_at_v1';

  static Future<void> show(BuildContext context) async {
    final services = AppServices.instance;
    final catalog = await VaultProductionCatalog.build();
    final identity = services.syncIdentity;
    if (identity == null || services.biometricVault == null) {
      throw StateError('Encrypted portability is unavailable in this runtime.');
    }
    final vault = services.biometricVault!;
    final keys = ProductionVaultPortableKeys(
      privateKeyStore: SecurePrivateDataEncryptionKeyStore(
        secure: services.secureStorage,
      ),
      biometricVault: vault,
      liveAudioKeys: services.vaultKeyProvider,
      syncIdentity: identity,
    );
    final lifecycle = ProductionVaultLifecycle(
      transcriptionPause: () async =>
          AppServices.instance.transcriptionQueueExecutor.pause(),
      transcriptionResume: () async =>
          AppServices.instance.transcriptionQueueExecutor.resume(),
      syncEngine: services.e2eeSyncEngine,
      currentSyncEngine: () => AppServices.instance.e2eeSyncEngine,
      meshPause: () async => services.meshSyncEngine?.quiesce(),
      meshResume: () async => AppServices.instance.meshSyncEngine?.resume(),
      checkpointDatabases: () async {
        services.transcriptionLedger.checkpoint();
        services.syncOutbox?.checkpoint();
        await services.horizonLabService.checkpoint();
      },
      closeStoresForRestore: AppServices.shutdownForVaultRestore,
      reopenStoresAfterRestore: ({required succeeded}) async {
        await AppServices.initialize();
        await AppServices.instance.e2eeSyncEngine
            ?.reinitializeVectorClockFromOutbox();
      },
    );
    final backup = VaultBackupService(
      catalog: catalog,
      keyProvider: keys,
      lifecycle: lifecycle,
    );
    final restore = VaultRestoreService(
      catalog: catalog,
      keyInstaller: keys,
      lifecycle: lifecycle,
      notifier: ProductionVaultRestoreNotifier(
        // A newly initialized sync engine starts with the restored state. Do
        // not touch the disposed pre-restore engine while stores are closed.
        resetVectorClock: () async {},
        emitRestoreRevision: () async => AppServices.emitRestoreRevision(),
      ),
    );
    final markdown = MarkdownExportService(
      journalStore: services.journalStore,
      localSemanticStore: services.localSemanticStore,
      semanticClusterStore: services.semanticClusterStore,
      knowledgeGraphStore: services.personalKnowledgeGraphStore,
      authorization: BiometricVaultMarkdownExportAuthorization(vault),
      attachmentSource: AudioVaultAttachmentExportSource(
        journalStore: services.journalStore,
        audioVault: services.journalAudioVault,
      ),
    );
    final lastBackupText = await services.prefs.readString(_lastBackupKey);
    if (!context.mounted) return;

    await DataPortabilitySheet.show(
      context,
      lastBackupAt: DateTime.tryParse(lastBackupText ?? ''),
      onCreateBackup: (credential) async {
        if (!await vault.reauthenticateAndUnlock(
          reason: 'Confirm your identity to create an encrypted backup',
        )) {
          throw StateError('Device-owner authentication was not completed.');
        }
        final temporary = await AppStoragePaths.temporaryDirectory();
        final output = File(
          '${temporary.path}/archiveme-'
          '${DateTime.now().toUtc().microsecondsSinceEpoch}.memoryvault',
        );
        await backup.createBackup(
          output: output,
          credential: _credential(credential),
          includeSyncPhrase: true,
        );
        return output.path;
      },
      shareFile: (path) async {
        final file = File(path);
        try {
          final result = await Share.shareXFiles([
            XFile(path, mimeType: 'application/octet-stream'),
          ], subject: 'ArchiveMe encrypted backup');
          if (result.status != ShareResultStatus.success) {
            throw StateError('The encrypted backup was not shared.');
          }
          await AppServices.instance.prefs.writeString(
            _lastBackupKey,
            DateTime.now().toUtc().toIso8601String(),
          );
        } finally {
          if (path.toLowerCase().endsWith('.memoryvault')) {
            await _zeroAndDelete(file);
          }
        }
      },
      pickMemoryVaultFile: () async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['memoryvault'],
          allowMultiple: false,
        );
        return result?.files.single.path;
      },
      onRestoreBackup: (path, credential) async {
        await AppServices.instance.codexPublicationService?.onLockOrRestore();
        await restore.restore(
          input: File(path),
          credential: _credential(credential),
          mode: VaultRestoreMode.replace,
        );
      },
      onExportMarkdown: () async {
        final result = await markdown.export(explicitUserAction: true);
        if (!result.succeeded) {
          throw StateError(
            result.failure == MarkdownExportFailure.biometricDenied
                ? 'Device-owner authentication was not completed.'
                : 'The Markdown export could not be created.',
          );
        }
        return null;
      },
    );
  }

  static VaultCredential _credential(DataPortabilityCredential credential) =>
      switch (credential.mode) {
        DataPortabilityCredentialMode.recoveryPhrase => VaultCredential.bip39(
          credential.secret,
        ),
        DataPortabilityCredentialMode.customPassword =>
          VaultCredential.password(credential.secret),
      };

  static Future<void> _zeroAndDelete(File file) async {
    if (!await file.exists()) return;
    RandomAccessFile? handle;
    try {
      final length = await file.length();
      handle = await file.open(mode: FileMode.write);
      final zeroes = Uint8List(64 * 1024);
      var remaining = length;
      while (remaining > 0) {
        final count = remaining < zeroes.length ? remaining : zeroes.length;
        await handle.writeFrom(zeroes, 0, count);
        remaining -= count;
      }
      await handle.flush();
    } finally {
      await handle?.close();
      if (await file.exists()) await file.delete();
    }
  }
}
