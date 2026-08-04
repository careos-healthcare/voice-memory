import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/application/vault_sync_manager.dart';
import 'package:voicememory_mobile/features/live_audio/domain/vault_chunk_payload.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/emergency_vault_storage.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_upload_api_client.dart';

void main() {
  test(
    'LocalAudioVault -> EmergencyVaultStorage -> VaultSyncManager preserves encrypted bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'vault_chunk_e2e_chaos_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final storage = EmergencyVaultStorage(
        manifestFile: File('${root.path}/queue.json'),
        resolveChunkDirectory: () async => Directory('${root.path}/chunks'),
      );
      final upload = _GatedAckUploadClient();
      final manager = VaultSyncManager(
        vaultStorage: storage,
        apiClient: upload,
        enableConnectivityListener: false,
      );
      addTearDown(manager.dispose);
      final vault = LocalAudioVault(
        vaultKeyProvider: VaultKeyProvider.testing(),
        resolveCacheDirectory: () async {
          final directory = Directory('${root.path}/vaults');
          await directory.create(recursive: true);
          return directory;
        },
        emergencyChunkStorage: storage,
        onEmergencyChunkQueued: manager.processPendingVaultQueue,
      );
      final plaintext = Int16List.fromList([0x1234, -0x1234, 0x2345, -0x2345]);

      await vault.initializeVault('integration-chaos');
      vault.appendFrame(plaintext);
      final vaultFile = await vault.closeVault();
      await upload.entered.future;

      final queuedFiles = await Directory('${root.path}/chunks')
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.bin'))
          .cast<File>()
          .toList();
      expect(queuedFiles, hasLength(1));
      final durableBytes = await queuedFiles.single.readAsBytes();
      final fullVaultBytes = await vaultFile!.readAsBytes();
      expect(fullVaultBytes.sublist(10), durableBytes);
      expect(
        _containsSubsequence(
          durableBytes,
          plaintext.buffer.asUint8List(
            plaintext.offsetInBytes,
            plaintext.lengthInBytes,
          ),
        ),
        isFalse,
      );

      upload.release.complete();
      await upload.completed.future;
      await manager.processPendingVaultQueue();

      expect(upload.uploads.single.bytes, durableBytes);
      expect(await storage.getUnsyncedChunks(), isEmpty);
      expect(await queuedFiles.single.exists(), isFalse);
    },
  );
}

bool _containsSubsequence(List<int> haystack, List<int> needle) {
  for (var start = 0; start <= haystack.length - needle.length; start++) {
    var matches = true;
    for (var offset = 0; offset < needle.length; offset++) {
      if (haystack[start + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

class _GatedAckUploadClient implements VaultUploadApiClient {
  final entered = Completer<void>();
  final release = Completer<void>();
  final completed = Completer<void>();
  final uploads = <VaultChunkPayload>[];

  @override
  Future<bool> uploadVaultChunk(VaultChunkPayload chunk) async {
    uploads.add(chunk);
    if (!entered.isCompleted) entered.complete();
    await release.future;
    if (!completed.isCompleted) completed.complete();
    return true;
  }
}
