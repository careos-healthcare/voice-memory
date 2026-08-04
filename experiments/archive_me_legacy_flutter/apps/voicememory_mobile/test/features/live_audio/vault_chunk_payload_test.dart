import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:voicememory_mobile/features/live_audio/domain/vault_chunk_payload.dart';

void main() {
  group('VaultChunkPayload', () {
    test('stamps idempotency key on creation when omitted', () {
      final recordedAt = DateTime.utc(2026, 7, 20, 8, 0, 0);
      const chunkId = 'chunk-123';

      final payload = VaultChunkPayload(
        id: chunkId,
        sessionId: 'session_1',
        bytes: [1, 2, 3],
        recordedAt: recordedAt,
      );

      expect(
        payload.idempotencyKey,
        'session_1_chunk-123_${recordedAt.millisecondsSinceEpoch}',
      );
      expect(payload.isSynced, isFalse);
    });

    test('create factory assigns uuid id and utc recordedAt', () {
      final payload = VaultChunkPayload.create(
        sessionId: 'session_2',
        bytes: [9, 9],
        uuid: const Uuid(),
        id: 'fixed-id',
        recordedAt: DateTime.utc(2026, 1, 1),
      );

      expect(payload.id, 'fixed-id');
      expect(payload.sessionId, 'session_2');
      expect(payload.recordedAt.isUtc, isTrue);
    });

    test('toJson emits backend envelope fields without raw bytes', () {
      final payload = VaultChunkPayload(
        id: 'chunk-1',
        sessionId: 'session_1',
        bytes: [4, 5, 6, 7],
        recordedAt: DateTime.utc(2026, 7, 20, 8, 15),
        idempotencyKey: 'stable-key',
      );

      expect(payload.toJson(), {
        'id': 'chunk-1',
        'session_id': 'session_1',
        'byte_length': 4,
        'recorded_at': '2026-07-20T08:15:00.000Z',
        'idempotency_key': 'stable-key',
        'is_synced': false,
      });
    });

    test('fromJson rehydrates stored envelope with bytes', () {
      final payload = VaultChunkPayload.fromJson(
        {
          'id': 'chunk-1',
          'session_id': 'session_1',
          'byte_length': 2,
          'recorded_at': '2026-07-20T08:15:00.000Z',
          'idempotency_key': 'stable-key',
          'is_synced': true,
        },
        bytes: [1, 1],
      );

      expect(payload.bytes, [1, 1]);
      expect(payload.isSynced, isTrue);
      expect(payload.idempotencyKey, 'stable-key');
    });
  });
}
