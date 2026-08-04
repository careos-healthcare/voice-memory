import 'dart:typed_data';

import '../../features/live_audio/infrastructure/vault_key_provider.dart';
import '../../features/sync/encrypted_sync_engine.dart';
import '../../services/security/biometric_vault_service.dart';
import '../../services/security/sync_identity_service.dart';
import '../../storage/app_storage_paths.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'vault_backup_models.dart';

final class VaultProductionCatalog {
  const VaultProductionCatalog._();

  static Future<VaultSourceCatalog> build() async =>
      VaultSourceCatalog.production(
        await AppStoragePaths.applicationDocumentsDirectory(),
        supportRoot: await AppStoragePaths.applicationSupportDirectory(),
      );
}

/// Secure-storage keyring adapter. The keyring bytes are handed only to the
/// encrypted archive layer and every temporary byte buffer is zeroed.
final class ProductionVaultPortableKeys
    implements
        VaultPortableKeyProvider,
        VaultFinalizableTransactionalKeyInstaller {
  ProductionVaultPortableKeys({
    required this.privateKeyStore,
    required this.biometricVault,
    required this.liveAudioKeys,
    required this.syncIdentity,
  });

  final PrivateDataEncryptionKeyStore privateKeyStore;
  final BiometricVaultService biometricVault;
  final VaultKeyProvider liveAudioKeys;
  final SyncIdentityService syncIdentity;

  Uint8List? _previousPrivateKey;
  VaultKeyReplacement? _liveAudioReplacement;
  String? _previousPhrase;
  bool _phraseWasInstalled = false;
  BiometricVaultKeyReplacement? _biometricReplacement;

  @override
  Future<VaultPortableKeyring> exportPortableKeys({
    required bool includeSyncPhrase,
  }) async {
    final privateBytes = await privateKeyStore.readKeyBytes();
    if (privateBytes == null || privateBytes.length != 32) {
      privateBytes?.fillRange(0, privateBytes.length, 0);
      throw const VaultBackupValidationException(
        'The private-data encryption key is unavailable.',
      );
    }
    final privateKey = Uint8List.fromList(privateBytes);
    privateBytes.fillRange(0, privateBytes.length, 0);
    final audioKey = await liveAudioKeys.exportMasterKey();
    try {
      return VaultPortableKeyring(
        keys: {
          VaultPortableKey.privateDataEncryption: privateKey,
          VaultPortableKey.biometricVault: privateKey,
          VaultPortableKey.liveAudioVault: audioKey,
        },
        syncPhrase: includeSyncPhrase
            ? await syncIdentity.recoveryPhrase()
            : null,
      );
    } finally {
      privateKey.fillRange(0, privateKey.length, 0);
      audioKey.fillRange(0, audioKey.length, 0);
    }
  }

  @override
  Future<void> install(VaultPortableKeyring keyring) async {
    if (_previousPrivateKey != null ||
        _liveAudioReplacement != null ||
        _biometricReplacement != null) {
      throw StateError('A portable key installation is already active.');
    }
    final privateKey =
        keyring.keys[VaultPortableKey.biometricVault] ??
        keyring.keys[VaultPortableKey.privateDataEncryption];
    final audioKey = keyring.keys[VaultPortableKey.liveAudioVault];
    if (privateKey == null ||
        privateKey.length != 32 ||
        audioKey == null ||
        audioKey.length != VaultKeyProvider.keyByteLength) {
      throw const VaultBackupValidationException(
        'The backup portable keyring is incomplete.',
      );
    }
    try {
      final previous = await privateKeyStore.readKeyBytes();
      _previousPrivateKey = previous == null
          ? null
          : Uint8List.fromList(previous);
      previous?.fillRange(0, previous.length, 0);

      if (biometricVault.isEnabled) {
        _biometricReplacement = await biometricVault.replaceMasterKeyForRestore(
          Uint8List.fromList(privateKey),
        );
        if (_biometricReplacement == null) {
          throw const VaultRestoreException(
            'Device-owner authentication was not completed.',
          );
        }
      } else {
        await privateKeyStore.writeKeyBytes(privateKey);
      }
      _liveAudioReplacement = await liveAudioKeys.installMasterKey(
        Uint8List.fromList(audioKey),
      );
      final phrase = keyring.syncPhrase;
      if (phrase != null) {
        _previousPhrase = await syncIdentity.recoveryPhrase();
        await syncIdentity.installRecoveryPhrase(phrase);
        _phraseWasInstalled = true;
      }
    } on Object {
      await rollback();
      rethrow;
    }
  }

  @override
  Future<void> rollback() async {
    final phraseInstalled = _phraseWasInstalled;
    final previousPhrase = _previousPhrase;
    _phraseWasInstalled = false;
    _previousPhrase = null;
    if (phraseInstalled) {
      if (previousPhrase == null) {
        await syncIdentity.disable();
      } else {
        await syncIdentity.installRecoveryPhrase(previousPhrase);
      }
    }

    final liveReplacement = _liveAudioReplacement;
    _liveAudioReplacement = null;
    if (liveReplacement != null) {
      await liveAudioKeys.rollbackMasterKey(liveReplacement);
    }

    final biometricReplacement = _biometricReplacement;
    _biometricReplacement = null;
    if (biometricReplacement != null) {
      await biometricVault.rollbackMasterKeyReplacement(biometricReplacement);
      _previousPrivateKey?.fillRange(0, _previousPrivateKey!.length, 0);
    } else {
      final previous = _previousPrivateKey;
      if (previous == null) {
        await privateKeyStore.deleteKey();
      } else {
        try {
          await privateKeyStore.writeKeyBytes(previous);
        } finally {
          previous.fillRange(0, previous.length, 0);
        }
      }
    }
    _previousPrivateKey = null;
  }

  @override
  Future<void> commit() async {
    // Installation is already durable. Retain rollback material until stores
    // have reopened successfully.
  }

  @override
  Future<void> finalizeCommit() async {
    final liveReplacement = _liveAudioReplacement;
    if (liveReplacement != null) {
      liveAudioKeys.commitMasterKey(liveReplacement);
    }
    final biometricReplacement = _biometricReplacement;
    if (biometricReplacement != null) {
      biometricVault.commitMasterKeyReplacement(biometricReplacement);
    }
    _previousPrivateKey?.fillRange(0, _previousPrivateKey!.length, 0);
    _previousPrivateKey = null;
    _liveAudioReplacement = null;
    _biometricReplacement = null;
    _previousPhrase = null;
    _phraseWasInstalled = false;
  }
}

typedef VaultLifecycleCallback = Future<void> Function();
typedef VaultRestoreFinishedCallback =
    Future<void> Function({required bool succeeded});

final class ProductionVaultLifecycle implements VaultRestoreLifecycle {
  ProductionVaultLifecycle({
    required this.transcriptionPause,
    required this.transcriptionResume,
    required this.syncEngine,
    this.currentSyncEngine,
    this.meshPause,
    this.meshResume,
    required this.checkpointDatabases,
    required this.closeStoresForRestore,
    required this.reopenStoresAfterRestore,
  });

  final VaultLifecycleCallback transcriptionPause;
  final VaultLifecycleCallback transcriptionResume;
  final EncryptedSyncEngine? syncEngine;
  final EncryptedSyncEngine? Function()? currentSyncEngine;
  final VaultLifecycleCallback? meshPause;
  final VaultLifecycleCallback? meshResume;
  final VaultLifecycleCallback checkpointDatabases;
  final VaultLifecycleCallback closeStoresForRestore;
  final VaultRestoreFinishedCallback reopenStoresAfterRestore;
  bool _restorePrepared = false;

  @override
  Future<void> quiesce() async {
    await transcriptionPause();
    await meshPause?.call();
    await syncEngine?.quiesce();
    await checkpointDatabases();
  }

  @override
  Future<void> prepareRestore() async {
    await closeStoresForRestore();
    _restorePrepared = true;
  }

  @override
  Future<void> finishRestore({required bool succeeded}) async {
    await reopenStoresAfterRestore(succeeded: succeeded);
  }

  @override
  Future<void> resume() async {
    if (_restorePrepared) {
      currentSyncEngine?.call()?.resume();
    } else {
      syncEngine?.resume();
    }
    await meshResume?.call();
    await transcriptionResume();
    _restorePrepared = false;
  }

  @override
  Future<void> closeAfterFailedReopen() => closeStoresForRestore();
}

final class ProductionVaultRestoreNotifier implements VaultRestoreNotifier {
  ProductionVaultRestoreNotifier({
    required this.resetVectorClock,
    required this.emitRestoreRevision,
  });

  final VaultLifecycleCallback resetVectorClock;
  final VaultLifecycleCallback emitRestoreRevision;

  @override
  Future<void> resetSyncState() => resetVectorClock();

  @override
  Future<void> notifyProviders() => emitRestoreRevision();
}
