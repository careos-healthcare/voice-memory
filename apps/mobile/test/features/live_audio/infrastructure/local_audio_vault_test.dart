import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/live_audio/infrastructure/local_audio_vault.dart';
import 'package:archiveme_mobile/features/live_audio/live_audio_constants.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalAudioVault', () {
    late Directory vaultDirectory;
    late InMemoryPrivateDataEncryptionKeyStore keyStore;
    late LocalAudioVault vault;

    setUp(() async {
      vaultDirectory = await Directory.systemTemp.createTemp(
        'local_audio_vault_',
      );
      keyStore = InMemoryPrivateDataEncryptionKeyStore();
      await keyStore.ensureKey();
      vault = LocalAudioVault(
        keyStore: keyStore,
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