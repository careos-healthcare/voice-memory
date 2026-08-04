import '../../sync/encrypted_sync_engine.dart';
import 'mesh_sync_checkpoint.dart';
import 'mesh_sync_models.dart';
import 'peer_sync_channel.dart';

class MeshChunkApplyResult {
  const MeshChunkApplyResult({
    required this.acknowledgement,
    required this.appliedWinnerCount,
    required this.wasDuplicate,
  });

  final Map<String, dynamic> acknowledgement;
  final int appliedWinnerCount;
  final bool wasDuplicate;
}

/// Differential, transport-neutral CRDT exchange over an authenticated peer.
class MeshSyncReconciler {
  MeshSyncReconciler({
    required this.engine,
    required this.checkpoints,
    this.maxOperationsPerChunk = 32,
    this.maxEncodedBytesPerChunk = 256 * 1024,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (maxOperationsPerChunk < 1 || maxEncodedBytesPerChunk < 1) {
      throw ArgumentError('Mesh chunk bounds must be positive.');
    }
  }

  final EncryptedSyncEngine engine;
  final EncryptedMeshCheckpointStore checkpoints;
  final int maxOperationsPerChunk;
  final int maxEncodedBytesPerChunk;
  final DateTime Function() _clock;

  Future<Map<String, dynamic>> createHeadSummary() => engine.summarizeHeads();

  /// Creates the next bounded differential chunk and persists its cursor.
  Future<Map<String, dynamic>> exportNextChunk({
    required String peerId,
    required String exchangeId,
    required int sequence,
    required Map<String, dynamic> peerSummary,
  }) async {
    if (sequence < 0) throw ArgumentError.value(sequence, 'sequence');
    final existing = await checkpoints.load(peerId);
    final checkpoint = existing != null && existing.exchangeId == exchangeId
        ? existing
        : MeshSyncCheckpoint(exchangeId: exchangeId, updatedAt: _clock());
    final chunkId = '$exchangeId:$sequence';
    final retained = checkpoint.outboundChunks[chunkId];
    if (retained != null) return Map<String, dynamic>.from(retained);
    final page = MeshExportPage.fromJson(
      await engine.exportMissingWinners(
        peerSummary,
        afterEntityKey: checkpoint.outboundCursor,
        maxOperations: maxOperationsPerChunk,
        maxEncodedBytes: maxEncodedBytesPerChunk,
      ),
    );
    final chunk = <String, dynamic>{
      'version': meshSyncProtocolVersion,
      'type': 'crdt_chunk',
      'exchangeId': exchangeId,
      'chunkId': chunkId,
      'sequence': sequence,
      'sourceDeviceId': engine.deviceId,
      'isLast': page.isComplete,
      'envelopes': page.envelopes
          .map((envelope) => envelope.toRelayBlob())
          .toList(growable: false),
    };
    await checkpoints.save(
      peerId,
      checkpoint.copyWith(
        outboundCursor: page.nextCursor,
        clearOutboundCursor: page.isComplete && page.nextCursor == null,
        outboundChunks: {...checkpoint.outboundChunks, chunkId: chunk},
        updatedAt: _clock(),
      ),
    );
    return chunk;
  }

  /// Applies a chunk from a secure channel in any order and returns a local
  /// mesh acknowledgement. The acknowledgement only updates mesh checkpoint
  /// state; it never marks cloud outbox rows delivered.
  Future<MeshChunkApplyResult> applyAuthenticatedChunk({
    required String authenticatedPeerId,
    required Map<String, dynamic> chunk,
  }) async {
    _validatePacket(chunk, expectedType: 'crdt_chunk');
    if ('${chunk['sourceDeviceId']}' != authenticatedPeerId) {
      throw StateError('Chunk source does not match authenticated peer.');
    }
    final exchangeId = '${chunk['exchangeId']}';
    final chunkId = '${chunk['chunkId']}';
    if (exchangeId.isEmpty || chunkId.isEmpty) {
      throw const FormatException('Mesh chunk identifiers are required.');
    }
    final existing = await checkpoints.load(authenticatedPeerId);
    final checkpoint = existing != null && existing.exchangeId == exchangeId
        ? existing
        : MeshSyncCheckpoint(exchangeId: exchangeId, updatedAt: _clock());
    if (checkpoint.receivedChunkIds.contains(chunkId)) {
      return MeshChunkApplyResult(
        acknowledgement: _ack(exchangeId, chunkId),
        appliedWinnerCount: 0,
        wasDuplicate: true,
      );
    }
    final rawEnvelopes = chunk['envelopes'];
    if (rawEnvelopes is! List) {
      throw const FormatException('Mesh chunk is missing envelopes.');
    }
    final envelopes = rawEnvelopes
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (envelopes.length != rawEnvelopes.length) {
      throw const FormatException('Mesh chunk contains an invalid envelope.');
    }
    final result = await engine.applyAuthenticatedPeerEnvelopes(
      envelopes,
      authenticatedPeerId: authenticatedPeerId,
    );
    await checkpoints.save(
      authenticatedPeerId,
      checkpoint.copyWith(
        receivedChunkIds: {...checkpoint.receivedChunkIds, chunkId},
        updatedAt: _clock(),
      ),
    );
    return MeshChunkApplyResult(
      acknowledgement: _ack(exchangeId, chunkId),
      appliedWinnerCount: result.appliedWinnerCount,
      wasDuplicate: false,
    );
  }

  Future<void> applyAcknowledgement({
    required String authenticatedPeerId,
    required Map<String, dynamic> acknowledgement,
  }) async {
    _validatePacket(acknowledgement, expectedType: 'crdt_ack');
    if ('${acknowledgement['sourceDeviceId']}' != authenticatedPeerId) {
      throw StateError(
        'Acknowledgement source does not match authenticated peer.',
      );
    }
    final exchangeId = '${acknowledgement['exchangeId']}';
    final checkpoint = await checkpoints.load(authenticatedPeerId);
    if (checkpoint == null || checkpoint.exchangeId != exchangeId) {
      throw StateError('Acknowledgement does not match the active exchange.');
    }
    final chunkId = '${acknowledgement['chunkId']}';
    if (!checkpoint.outboundChunks.containsKey(chunkId) &&
        !checkpoint.acknowledgedChunkIds.contains(chunkId)) {
      throw StateError('Acknowledgement references an unknown mesh chunk.');
    }
    final remainingChunks = Map<String, Map<String, dynamic>>.from(
      checkpoint.outboundChunks,
    )..remove(chunkId);
    await checkpoints.save(
      authenticatedPeerId,
      checkpoint.copyWith(
        acknowledgedChunkIds: {...checkpoint.acknowledgedChunkIds, chunkId},
        outboundChunks: remainingChunks,
        updatedAt: _clock(),
      ),
    );
  }

  /// Sends a previously serialized packet through the locally defined secure
  /// channel seam. This keeps reconciliation independent of channel packages.
  Future<void> send(
    AuthenticatedPeerSyncChannel channel,
    Map<String, dynamic> packet,
  ) => channel.send(packet);

  Map<String, dynamic> _ack(String exchangeId, String chunkId) => {
    'version': meshSyncProtocolVersion,
    'type': 'crdt_ack',
    'exchangeId': exchangeId,
    'chunkId': chunkId,
    'sourceDeviceId': engine.deviceId,
  };

  void _validatePacket(
    Map<String, dynamic> packet, {
    required String expectedType,
  }) {
    if ((packet['version'] as num?)?.toInt() != meshSyncProtocolVersion) {
      throw const FormatException('Unsupported mesh sync packet version.');
    }
    if (packet['type'] != expectedType) {
      throw FormatException('Expected mesh packet type $expectedType.');
    }
  }
}
