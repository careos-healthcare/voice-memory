import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/emergency_vault_storage.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/local_audio_vault_reader.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_cipher.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';

void main() {
  group('LocalAudioVault', () {
    late Directory vaultDirectory;
    late VaultKeyProvider vaultKeyProvider;
    late LocalAudioVault vault;

    setUp(() async {
      vaultDirectory = await Directory.systemTemp.createTemp(
        'local_audio_vault_',
      );
      vaultKeyProvider = VaultKeyProvider.testing();
      vault = LocalAudioVault(
        vaultKeyProvider: vaultKeyProvider,
        resolveCacheDirectory: () async => vaultDirectory,
      );
    });

    tearDown(() async {
      if (vaultDirectory.existsSync()) {
        await vaultDirectory.delete(recursive: true);
      }
    });

    test('writes encrypted append-only vault with AVME header', () async {
      await vault.initializeVault('session_test');

      final frame = Int16List.fromList([100, -200, 300, -400]);
      vault.appendFrame(frame);
      vault.appendFrame(frame);
      await vault.closeVault();

      final files = vaultDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.vault.enc'))
          .toList();
      expect(files, hasLength(1));

      final bytes = await files.first.readAsBytes();
      expect(bytes.sublist(0, 4), [0x41, 0x56, 0x4d, 0x45]);
      expect(bytes[4], 1);
      expect(
        bytes.buffer.asByteData().getUint32(5, Endian.little),
        liveInputSampleRateHz,
      );
      expect(bytes[9], liveInputNumChannels);

      final plaintextNeedle = frame.buffer.asUint8List(
        frame.offsetInBytes,
        frame.lengthInBytes,
      );
      expect(bytes.indexOfSlice(plaintextNeedle), lessThan(0));
      expect(vault.frameCount, 2);
    });

    test('appendPcm16LeBytes accepts raw capture callback bytes', () async {
      await vault.initializeVault('session_bytes');
      final pcmBytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      vault.appendPcm16LeBytes(pcmBytes);
      await vault.closeVault();

      expect(vault.frameCount, 1);
      expect(vault.activeFile, isNotNull);
    });

    test('closeVault flushes pending encrypted writes', () async {
      await vault.initializeVault('session_flush');
      for (var i = 0; i < 20; i++) {
        vault.appendFrame(
          Int16List.fromList(List<int>.generate(320, (j) => j + i)),
        );
      }

      final file = await vault.closeVault();
      expect(file, isNotNull);
      expect(await file!.length(), greaterThan(10));
      expect(vault.isActive, isFalse);
    });

    test(
      'appendFrame enqueues encrypted records into emergency chunk storage',
      () async {
        final chunkDirectory = Directory('${vaultDirectory.path}/chunks');
        final chunkStorage = EmergencyVaultStorage(
          manifestFile: File('${vaultDirectory.path}/chunk_queue.json'),
          resolveChunkDirectory: () async => chunkDirectory,
        );
        var queuedSyncCount = 0;
        final syncingVault = LocalAudioVault(
          vaultKeyProvider: vaultKeyProvider,
          resolveCacheDirectory: () async => vaultDirectory,
          emergencyChunkStorage: chunkStorage,
          onEmergencyChunkQueued: () async {
            queuedSyncCount++;
          },
        );

        await syncingVault.initializeVault('session_sync');
        syncingVault.appendFrame(Int16List.fromList([10, 20, 30, 40]));
        syncingVault.appendFrame(Int16List.fromList([50, 60, 70, 80]));
        await syncingVault.closeVault();

        final pending = await chunkStorage.getUnsyncedChunks();
        expect(pending, hasLength(2));
        expect(
          pending.every((chunk) => chunk.sessionId == 'session_sync'),
          isTrue,
        );
        expect(pending.every((chunk) => chunk.bytes.isNotEmpty), isTrue);
        expect(queuedSyncCount, 2);
      },
    );

    test(
      'emergency chunk bytes use uint32 + VaultCipher authenticated blob',
      () async {
        final chunkDirectory = Directory(
          '${vaultDirectory.path}/chunks_layout',
        );
        final chunkStorage = EmergencyVaultStorage(
          manifestFile: File('${vaultDirectory.path}/chunk_queue_layout.json'),
          resolveChunkDirectory: () async => chunkDirectory,
        );
        final syncingVault = LocalAudioVault(
          vaultKeyProvider: vaultKeyProvider,
          resolveCacheDirectory: () async => vaultDirectory,
          emergencyChunkStorage: chunkStorage,
        );

        final frame = Int16List.fromList([100, -200, 300, -400]);
        await syncingVault.initializeVault('session_layout');
        syncingVault.appendFrame(frame);
        await syncingVault.closeVault();

        final pending = await chunkStorage.getUnsyncedChunks();
        expect(pending, hasLength(1));

        final record = Uint8List.fromList(pending.single.bytes);
        expect(
          record.length,
          greaterThan(4 + VaultCipher.authenticatedOverhead),
        );

        final cipherTextLength = VaultCipher.vaultFrameRecordLength(record, 0);
        expect(cipherTextLength, isNotNull);
        expect(record.length, cipherTextLength);
      },
    );

    test(
      'round-trips encrypted vault frames through LocalAudioVaultReader',
      () async {
        final frame = Int16List.fromList([100, -200, 300, -400, 500, -600]);
        await vault.initializeVault('session_roundtrip');
        vault.appendFrame(frame);
        vault.appendPcm16LeBytes(Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]));
        final file = await vault.closeVault();

        final reader = LocalAudioVaultReader(
          vaultKeyProvider: vaultKeyProvider,
        );
        final pcmBytes = await reader.decryptVaultFile(file!);

        final expectedFrameBytes = frame.buffer.asUint8List(
          frame.offsetInBytes,
          frame.lengthInBytes,
        );
        expect(
          pcmBytes,
          Uint8List.fromList([...expectedFrameBytes, 0, 1, 2, 3, 4, 5, 6, 7]),
        );
      },
    );
  });
}

extension on List<int> {
  int indexOfSlice(List<int> slice) {
    if (slice.isEmpty) {
      return 0;
    }
    for (var i = 0; i <= length - slice.length; i++) {
      var matched = true;
      for (var j = 0; j < slice.length; j++) {
        if (this[i + j] != slice[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }
}
