import 'dart:async';

import '../../../storage/encrypted_json_file_store.dart';

/// Reconnect state for a single authenticated peer.
///
/// Implementations must encrypt serialized checkpoint data at rest. Keeping
/// persistence injectable lets the mesh layer use the platform secure channel
/// store without depending on a specific discovery or transport package.
abstract class EncryptedMeshCheckpointStore {
  Future<MeshSyncCheckpoint?> load(String peerId);

  Future<void> save(String peerId, MeshSyncCheckpoint checkpoint);

  Future<void> remove(String peerId);
}

class EncryptedFileMeshCheckpointStore implements EncryptedMeshCheckpointStore {
  EncryptedFileMeshCheckpointStore(this._storage);

  final EncryptedJsonFileStore _storage;
  Future<void> _tail = Future.value();

  @override
  Future<MeshSyncCheckpoint?> load(String peerId) => _serialize(() async {
    final values = await _read();
    final value = values[peerId];
    return value == null ? null : MeshSyncCheckpoint.fromJson(value);
  });

  @override
  Future<void> save(String peerId, MeshSyncCheckpoint checkpoint) =>
      _serialize(() async {
        final values = await _read();
        values[peerId] = checkpoint.toJson();
        await _storage.writeJson({'version': 1, 'checkpoints': values});
      });

  @override
  Future<void> remove(String peerId) => _serialize(() async {
    final values = await _read()
      ..remove(peerId);
    await _storage.writeJson({'version': 1, 'checkpoints': values});
  });

  Future<Map<String, Map<String, dynamic>>> _read() async {
    final raw = await _storage.readJson();
    if (raw == null) return {};
    if (raw is! Map || raw['version'] != 1 || raw['checkpoints'] is! Map) {
      throw const FormatException('Invalid encrypted mesh checkpoints.');
    }
    return {
      for (final entry in (raw['checkpoints'] as Map).entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: Map<String, dynamic>.from(entry.value as Map),
    };
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        result.complete(await operation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

class MeshSyncCheckpoint {
  MeshSyncCheckpoint({
    required this.exchangeId,
    this.outboundCursor,
    Set<String> receivedChunkIds = const {},
    Set<String> acknowledgedChunkIds = const {},
    Map<String, Map<String, dynamic>> outboundChunks = const {},
    DateTime? updatedAt,
  }) : receivedChunkIds = Set.unmodifiable(receivedChunkIds),
       acknowledgedChunkIds = Set.unmodifiable(acknowledgedChunkIds),
       outboundChunks = Map.unmodifiable(outboundChunks),
       updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  factory MeshSyncCheckpoint.fromJson(Map<String, dynamic> json) =>
      MeshSyncCheckpoint(
        exchangeId: '${json['exchangeId']}',
        outboundCursor: json['outboundCursor'] as String?,
        receivedChunkIds: _strings(json['receivedChunkIds']),
        acknowledgedChunkIds: _strings(json['acknowledgedChunkIds']),
        outboundChunks: _packets(json['outboundChunks']),
        updatedAt: DateTime.tryParse('${json['updatedAt']}'),
      );

  final String exchangeId;
  final String? outboundCursor;
  final Set<String> receivedChunkIds;
  final Set<String> acknowledgedChunkIds;
  final Map<String, Map<String, dynamic>> outboundChunks;
  final DateTime updatedAt;

  MeshSyncCheckpoint copyWith({
    String? outboundCursor,
    bool clearOutboundCursor = false,
    Set<String>? receivedChunkIds,
    Set<String>? acknowledgedChunkIds,
    Map<String, Map<String, dynamic>>? outboundChunks,
    DateTime? updatedAt,
  }) => MeshSyncCheckpoint(
    exchangeId: exchangeId,
    outboundCursor: clearOutboundCursor
        ? null
        : (outboundCursor ?? this.outboundCursor),
    receivedChunkIds: receivedChunkIds ?? this.receivedChunkIds,
    acknowledgedChunkIds: acknowledgedChunkIds ?? this.acknowledgedChunkIds,
    outboundChunks: outboundChunks ?? this.outboundChunks,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'exchangeId': exchangeId,
    'outboundCursor': outboundCursor,
    'receivedChunkIds': receivedChunkIds.toList()..sort(),
    'acknowledgedChunkIds': acknowledgedChunkIds.toList()..sort(),
    'outboundChunks': outboundChunks,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

Set<String> _strings(Object? raw) =>
    raw is List ? raw.map((item) => '$item').toSet() : const {};

Map<String, Map<String, dynamic>> _packets(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value is Map)
        '${entry.key}': Map<String, dynamic>.from(entry.value as Map),
  };
}
