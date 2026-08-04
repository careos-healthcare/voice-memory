import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:voicememory_mobile/features/live_audio/domain/retry_policy.dart';
import 'package:voicememory_mobile/features/live_audio/domain/vault_chunk_payload.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/local_audio_vault_reader.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_cipher.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_key_provider.dart';
import 'package:voicememory_mobile/features/live_audio/live_audio_constants.dart';

class FlakyVaultUploadApiClient {
  int failConsecutiveRequests;
  int successfulUploads = 0;
  final Set<String> processedIdempotencyKeys = {};

  FlakyVaultUploadApiClient({this.failConsecutiveRequests = 0});

  Future<bool> uploadVaultChunk({
    required String chunkId,
    required String sessionId,
    required List<int> audioBytes,
    required String idempotencyKey,
  }) async {
    if (failConsecutiveRequests > 0) {
      failConsecutiveRequests--;
      throw SocketException('Simulated network drop mid-chunk upload');
    }

    processedIdempotencyKeys.add(idempotencyKey);
    successfulUploads++;
    return true;
  }
}

Uint8List _vaultHeaderBytes() {
  final header = BytesBuilder(copy: false)
    ..add([0x41, 0x56, 0x4d, 0x45])
    ..add([1])
    ..add(_uint32Le(liveInputSampleRateHz))
    ..add([liveInputNumChannels]);
  return header.toBytes();
}

Uint8List _uint32Le(int value) {
  final bytes = Uint8List(4);
  bytes.buffer.asByteData().setUint32(0, value, Endian.little);
  return bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VaultKeyProvider keyProvider;
  late VaultCipher cipher;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vault_edge_case_test_');
    keyProvider = VaultKeyProvider.testing();
    cipher = VaultCipher();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Live Voice Recovery Gateway & Vault Edge Cases', () {
    test(
      'Scenario 1: Truncated file (OS crash mid-frame write) recovers valid prior frames',
      () async {
        final vaultFile = File('${tempDir.path}/crashed_session.vault.enc');
        final masterKey = await keyProvider.getOrCreateMasterKey();

        final pcmFrame1 = List<int>.generate(640, (i) => i % 256);
        final pcmFrame2 = List<int>.generate(640, (i) => (i + 10) % 256);

        final record1 = await cipher.encryptVaultFrameRecord(
          rawBytes: pcmFrame1,
          secretKey: masterKey,
        );
        final record2 = await cipher.encryptVaultFrameRecord(
          rawBytes: pcmFrame2,
          secretKey: masterKey,
        );

        final builder = BytesBuilder()
          ..add(_vaultHeaderBytes())
          ..add(record1)
          ..add(record2);

        final validBytes = builder.toBytes();

        final truncatedBytes = Uint8List.fromList([
          ...validBytes,
          0x00,
          0x00,
          0x02,
          0x00,
          0xAA,
          0xBB,
          0xCC,
        ]);

        await vaultFile.writeAsBytes(truncatedBytes);

        final reader = LocalAudioVaultReader(vaultKeyProvider: keyProvider);
        final recoveredFrames = await reader.readValidFrames(vaultFile);

        expect(recoveredFrames.length, equals(2));
        expect(recoveredFrames[0], equals(pcmFrame1));
        expect(recoveredFrames[1], equals(pcmFrame2));
      },
    );

    test(
      'Scenario 2: Network drop mid-chunk upload resumes and respects idempotency',
      () async {
        final apiClient = FlakyVaultUploadApiClient(failConsecutiveRequests: 2);

        final chunks = List.generate(
          5,
          (i) => VaultChunkPayload(
            id: 'chunk_$i',
            sessionId: 'session_123',
            bytes: List<int>.generate(320, (b) => b % 256),
            recordedAt: DateTime.now(),
            idempotencyKey: 'idem_key_$i',
          ),
        );

        const retryPolicy = RetryPolicy(
          maxAttempts: 4,
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
        );

        var attempts = 0;
        var uploadedCount = 0;

        for (final chunk in chunks) {
          var uploaded = false;
          var chunkAttempts = 0;

          while (!uploaded && retryPolicy.shouldRetry(chunkAttempts)) {
            chunkAttempts++;
            attempts++;
            try {
              uploaded = await apiClient.uploadVaultChunk(
                chunkId: chunk.id,
                sessionId: chunk.sessionId,
                audioBytes: chunk.bytes,
                idempotencyKey: chunk.idempotencyKey,
              );
            } catch (_) {
              // Simulated network exception handled by retry loop.
            }
          }

          if (uploaded) uploadedCount++;
        }

        expect(attempts, equals(7));
        expect(uploadedCount, equals(5));
        expect(apiClient.successfulUploads, equals(5));
        expect(apiClient.processedIdempotencyKeys.length, equals(5));
      },
    );

    test(
      'Scenario 3: Secure storage key cache reset mid-session recovers master key seamlessly',
      () async {
        final masterKeyBeforeReset = await keyProvider.getOrCreateMasterKey();

        final pcmBytes = List<int>.generate(640, (i) => 255 - (i % 256));
        final record = await cipher.encryptVaultFrameRecord(
          rawBytes: pcmBytes,
          secretKey: masterKeyBeforeReset,
        );

        keyProvider.clearCache();

        final masterKeyAfterReset = await keyProvider.getOrCreateMasterKey();
        final decrypted = await cipher.decryptVaultFrameRecord(
          encryptedRecordBytes: record,
          secretKey: masterKeyAfterReset,
        );

        expect(decrypted, equals(pcmBytes));
      },
    );
  });
}
