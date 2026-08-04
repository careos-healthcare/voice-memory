import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/emergency_vault_storage.dart';

void main() {
  group('EmergencyVaultStorage', () {
    late Directory tempDir;
    late File manifestFile;
    late EmergencyVaultStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'emergency_vault_storage_',
      );
      manifestFile = File('${tempDir.path}/queue.json');
      storage = EmergencyVaultStorage(
        manifestFile: manifestFile,
        resolveChunkDirectory: () async => Directory('${tempDir.path}/chunks'),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'enqueueChunk persists unsynced payload and stamped idempotency key',
      () async {
        final recordedAt = DateTime.utc(2026, 7, 20, 8, 15, 0);
        final chunk = await storage.enqueueChunk(
          sessionId: 'session_1',
          bytes: [1, 2, 3, 4],
          recordedAt: recordedAt,
        );

        expect(
          chunk.idempotencyKey,
          'session_1_${chunk.id}_${recordedAt.millisecondsSinceEpoch}',
        );
        expect(chunk.isSynced, isFalse);
        final pending = await storage.getUnsyncedChunks();
        expect(pending, hasLength(1));
        expect(pending.first.id, chunk.id);
        expect(pending.first.bytes, [1, 2, 3, 4]);
        expect(pending.first.idempotencyKey, chunk.idempotencyKey);
      },
    );

    test(
      'markChunkSynced and purgeSyncedChunks remove synced payloads',
      () async {
        final first = await storage.enqueueChunk(
          sessionId: 'session_1',
          bytes: [10],
        );
        final second = await storage.enqueueChunk(
          sessionId: 'session_1',
          bytes: [20],
        );

        await storage.markChunkSynced(first.id);
        expect((await storage.getUnsyncedChunks()).single.id, second.id);

        await storage.markChunkSynced(second.id);
        await storage.purgeSyncedChunks();

        expect(await storage.getUnsyncedChunks(), isEmpty);
        expect(await Directory('${tempDir.path}/chunks').list().length, 0);
      },
    );

    test(
      'parallel enqueues use unique monotonic per-session sequences',
      () async {
        await Future.wait(
          List<Future<Object?>>.generate(
            40,
            (index) => storage.enqueueChunk(
              sessionId: 'parallel',
              bytes: [index],
              idempotencyKey: 'key-$index',
            ),
          ),
        );

        final decoded = jsonDecode(await manifestFile.readAsString()) as List;
        final sequences =
            decoded
                .map(
                  (entry) => (entry as Map<String, dynamic>)['sequence'] as int,
                )
                .toList()
              ..sort();
        expect(sequences, List<int>.generate(40, (index) => index + 1));
        expect(
          (await storage.getUnsyncedChunks()).map((chunk) => chunk.bytes),
          {
            for (var index = 0; index < 40; index++) [index],
          },
        );
      },
    );

    test(
      'reconciles bytes flushed before manifest commit from sidecar',
      () async {
        final chunk = await storage.enqueueChunk(
          sessionId: 'crash-window',
          bytes: [0, 255, 17, 42],
          idempotencyKey: 'immutable-key',
          recordedAt: DateTime.utc(2026, 7, 26),
        );
        await manifestFile.delete();

        final restarted = EmergencyVaultStorage(
          manifestFile: manifestFile,
          resolveChunkDirectory: () async =>
              Directory('${tempDir.path}/chunks'),
        );
        final recovered = (await restarted.getUnsyncedChunks()).single;
        expect(recovered.id, chunk.id);
        expect(recovered.bytes, [0, 255, 17, 42]);
        expect(recovered.idempotencyKey, 'immutable-key');
        expect(await manifestFile.exists(), isTrue);
      },
    );

    test('corrupt partial manifest is rebuilt from atomic sidecars', () async {
      final first = await storage.enqueueChunk(
        sessionId: 'partial',
        bytes: [1, 3, 5],
      );
      final second = await storage.enqueueChunk(
        sessionId: 'partial',
        bytes: [2, 4, 6],
      );
      await manifestFile.writeAsString('[{"id":', flush: true);

      final restarted = EmergencyVaultStorage(
        manifestFile: manifestFile,
        resolveChunkDirectory: () async => Directory('${tempDir.path}/chunks'),
      );
      final recovered = await restarted.getUnsyncedChunks();
      expect(recovered.map((chunk) => chunk.id), [first.id, second.id]);
      expect(
        () => jsonDecode(manifestFile.readAsStringSync()),
        returnsNormally,
      );
    });

    test(
      'missing pending payload is typed, retained, and never synced',
      () async {
        final chunk = await storage.enqueueChunk(
          sessionId: 'integrity',
          bytes: [9, 8, 7],
        );
        final payload = File('${tempDir.path}/chunks/${chunk.id}.bin');
        await payload.delete();

        await expectLater(
          storage.getUnsyncedChunks(),
          throwsA(
            isA<EmergencyVaultIntegrityException>()
                .having(
                  (error) => error.issue,
                  'issue',
                  EmergencyVaultIntegrityIssue.missingPayload,
                )
                .having((error) => error.chunkIds, 'chunkIds', [chunk.id]),
          ),
        );
        expect(await storage.hasUncommittedChunks(), isTrue);
        expect(await manifestFile.readAsString(), contains(chunk.id));
      },
    );

    test(
      'mark survives restart and purge deletes only acknowledged files',
      () async {
        final acknowledged = await storage.enqueueChunk(
          sessionId: 'purge',
          bytes: [10, 11],
        );
        final pending = await storage.enqueueChunk(
          sessionId: 'purge',
          bytes: [20, 21],
        );
        await storage.markChunkSynced(acknowledged.id);

        final restarted = EmergencyVaultStorage(
          manifestFile: manifestFile,
          resolveChunkDirectory: () async =>
              Directory('${tempDir.path}/chunks'),
        );
        expect((await restarted.getUnsyncedChunks()).single.id, pending.id);
        await restarted.purgeSyncedChunks();
        expect(
          await File('${tempDir.path}/chunks/${acknowledged.id}.bin').exists(),
          isFalse,
        );
        expect(
          await File('${tempDir.path}/chunks/${pending.id}.bin').readAsBytes(),
          [20, 21],
        );
      },
    );

    test(
      'manifest and sidecar contain metadata but no payload bytes',
      () async {
        final bytes = utf8.encode('plaintext-audio-sentinel');
        final chunk = await storage.enqueueChunk(
          sessionId: 'privacy',
          bytes: bytes,
        );

        final manifestText = await manifestFile.readAsString();
        final sidecarText = await File(
          '${tempDir.path}/chunks/${chunk.id}.meta.json',
        ).readAsString();
        expect(manifestText, isNot(contains('plaintext-audio-sentinel')));
        expect(sidecarText, isNot(contains('plaintext-audio-sentinel')));
        expect(jsonDecode(manifestText), isA<List<dynamic>>());
        expect(jsonDecode(sidecarText), isA<Map<String, dynamic>>());
        expect(
          await File('${tempDir.path}/chunks/${chunk.id}.bin').readAsBytes(),
          bytes,
        );
      },
    );

    test('wipeAll removes pending payloads, sidecars, and manifest', () async {
      await storage.enqueueChunk(
        sessionId: 'privacy-wipe',
        bytes: [1, 2, 3, 4],
      );

      await storage.wipeAll();

      expect(await manifestFile.exists(), isFalse);
      expect(await Directory('${tempDir.path}/chunks').exists(), isFalse);
    });
  });
}
