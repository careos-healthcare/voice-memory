import 'package:uuid/uuid.dart';

/// Idempotent emergency vault chunk envelope stamped at creation time.
class VaultChunkPayload {
  VaultChunkPayload({
    required this.id,
    required this.sessionId,
    required this.bytes,
    required this.recordedAt,
    String? idempotencyKey,
    this.isSynced = false,
  }) : idempotencyKey =
           idempotencyKey ??
           '${sessionId}_${id}_${recordedAt.millisecondsSinceEpoch}';

  factory VaultChunkPayload.create({
    required String sessionId,
    required List<int> bytes,
    DateTime? recordedAt,
    String? id,
    String? idempotencyKey,
    Uuid? uuid,
  }) {
    final chunkId = id ?? (uuid ?? const Uuid()).v4();
    final createdAt = recordedAt ?? DateTime.now().toUtc();
    return VaultChunkPayload(
      id: chunkId,
      sessionId: sessionId,
      bytes: bytes,
      recordedAt: createdAt,
      idempotencyKey: idempotencyKey,
    );
  }

  factory VaultChunkPayload.fromJson(
    Map<String, dynamic> json, {
    required List<int> bytes,
  }) {
    return VaultChunkPayload(
      id: json['id'] as String,
      sessionId: (json['session_id'] ?? json['sessionId']) as String,
      bytes: bytes,
      recordedAt: DateTime.parse(
        (json['recorded_at'] ?? json['recordedAt']) as String,
      ),
      idempotencyKey:
          (json['idempotency_key'] ?? json['idempotencyKey']) as String?,
      isSynced:
          json['is_synced'] as bool? ?? json['isSynced'] as bool? ?? false,
    );
  }

  final String id;
  final String sessionId;
  final List<int> bytes;
  final DateTime recordedAt;
  final String idempotencyKey;
  final bool isSynced;

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'byte_length': bytes.length,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'idempotency_key': idempotencyKey,
    'is_synced': isSynced,
  };

  VaultChunkPayload copyWith({
    List<int>? bytes,
    DateTime? recordedAt,
    String? idempotencyKey,
    bool? isSynced,
  }) {
    return VaultChunkPayload(
      id: id,
      sessionId: sessionId,
      bytes: bytes ?? this.bytes,
      recordedAt: recordedAt ?? this.recordedAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
