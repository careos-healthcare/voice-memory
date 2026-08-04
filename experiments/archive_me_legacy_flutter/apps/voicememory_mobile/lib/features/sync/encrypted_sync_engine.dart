import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../models/journal_sync_metadata.dart';
import '../../models/journal_entry.dart';
import '../../services/ai/local_semantic_store.dart';
import '../../services/security/sync_identity_service.dart';
import '../action_plans/action_plan_models.dart';
import '../p2p_mesh/sync/mesh_sync_models.dart';
import '../semantic_clusters/semantic_cluster.dart';
import 'e2ee_sync_models.dart';
import 'sync_outbox.dart';

enum EncryptedSyncState { disabled, offline, syncing, upToDate, error }

class SyncDevice {
  const SyncDevice({
    required this.id,
    required this.lastSeenAt,
    required this.isCurrentDevice,
    required this.keyEpoch,
  });

  final String id;
  final DateTime lastSeenAt;
  final bool isCurrentDevice;
  final int keyEpoch;
}

abstract class E2EERelayTransport {
  Future<void> push(E2EESyncEnvelope envelope);
  Future<List<E2EESyncEnvelope>> pull();
}

class EncryptedSyncEngine {
  EncryptedSyncEngine({
    required this.deviceId,
    required this.identity,
    required this.outbox,
    required this.transport,
    required this.graphStore,
    required this.semanticStore,
    required FutureOr<bool> Function() isOnline,
    DateTime Function()? clock,
    Future<void> Function(CrdtOperation operation)? applyAuxiliaryOperation,
    // ignore: prefer_initializing_formals
  }) : _isOnline = isOnline,
       _clock = clock ?? DateTime.now,
       // ignore: prefer_initializing_formals
       _applyAuxiliaryOperation = applyAuxiliaryOperation;

  final String deviceId;
  final SyncIdentityService identity;
  final SyncOutbox outbox;
  final E2EERelayTransport transport;
  final PersonalKnowledgeGraphStore graphStore;
  final LocalSemanticStore semanticStore;
  final FutureOr<bool> Function() _isOnline;
  final DateTime Function() _clock;
  final Future<void> Function(CrdtOperation operation)?
  _applyAuxiliaryOperation;
  static const maxRelayBatchOperations = 32;
  static const maxRelayBatchCleartextBytes = 180 * 1024;
  static const maxPendingOperationsPerSync = 256;
  final _states = StreamController<EncryptedSyncState>.broadcast();
  final _devices = <String, SyncDevice>{};
  var _state = EncryptedSyncState.disabled;
  var _vectorClock = <String, int>{};
  bool _syncing = false;
  bool _applyingRemote = false;
  bool _peerReconciling = false;
  bool _paused = false;
  Timer? _periodicTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  EncryptedSyncState get state => _state;
  Stream<EncryptedSyncState> get states => _states.stream;
  List<SyncDevice> get devices =>
      _devices.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  bool get isApplyingRemote => _applyingRemote;
  bool get isPaused => _paused;

  /// Prevents new local writes/sync work and waits for an in-flight sync.
  Future<void> quiesce() async {
    _paused = true;
    while (_syncing || _applyingRemote || _peerReconciling) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void resume() => _paused = false;

  Future<void> beginPeerReconciliation() async {
    if (_paused || _peerReconciling) {
      throw StateError(
        'Encrypted sync is unavailable for mesh reconciliation.',
      );
    }
    while (_syncing || _applyingRemote) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    if (_paused) {
      throw StateError('Encrypted sync was paused before mesh reconciliation.');
    }
    _peerReconciling = true;
  }

  void endPeerReconciliation() {
    _peerReconciling = false;
  }

  void resetVectorClock() {
    if (!_paused || _syncing || _applyingRemote) {
      throw StateError('Encrypted sync must be quiesced before clock reset.');
    }
    _vectorClock = {};
    _devices.clear();
  }

  /// Rebuilds the local logical clock from restored encrypted CRDT heads.
  ///
  /// This prevents a same-device restore from reusing operation identifiers
  /// such as `deviceId-1` when the restored outbox already contains them.
  Future<void> reinitializeVectorClockFromOutbox() async {
    if (_syncing || _applyingRemote) {
      throw StateError('Encrypted sync must be idle before clock restore.');
    }
    if (!await identity.isEnabled) {
      _vectorClock = {};
      return;
    }
    final key = await identity.requireKey();
    try {
      final heads = await outbox.heads(key: key);
      _vectorClock = _mergedClock(
        heads.values.map((operation) => operation.vectorClock),
      );
    } finally {
      key.destroy();
    }
  }

  /// Produces a transport-neutral, payload-free summary of current LWW heads.
  Future<Map<String, dynamic>> summarizeHeads() async {
    final key = await identity.requireKey();
    try {
      final heads = await outbox.orderedHeads(key: key);
      return MeshHeadSummary(
        deviceId: deviceId,
        keyEpoch: await identity.keyEpoch,
        heads: {
          for (final entry in heads)
            entry.key: MeshHeadVersion.fromOperation(entry.value),
        },
      ).toJson();
    } finally {
      key.destroy();
    }
  }

  /// Exports only local LWW winners that beat [serializedPeerSummary].
  ///
  /// Each operation has its own authenticated E2EE envelope so chunks may be
  /// reordered or deduplicated independently. This reads CRDT heads directly
  /// and deliberately never consumes cloud-pending outbox rows.
  Future<Map<String, dynamic>> exportMissingWinners(
    Map<String, dynamic> serializedPeerSummary, {
    String? afterEntityKey,
    int maxOperations = 32,
    int maxEncodedBytes = 256 * 1024,
  }) async {
    if (maxOperations < 1 || maxEncodedBytes < 1) {
      throw ArgumentError('Mesh export bounds must be positive.');
    }
    final peerSummary = MeshHeadSummary.fromJson(serializedPeerSummary);
    final epoch = await identity.keyEpoch;
    if (peerSummary.keyEpoch != epoch) {
      throw StateError('Peer key epoch does not match local key epoch.');
    }
    final key = await identity.requireKey();
    try {
      final heads = await outbox.orderedHeads(
        key: key,
        afterEntityKey: afterEntityKey,
      );
      final envelopes = <E2EESyncEnvelope>[];
      var encodedBytes = 0;
      String? cursor = afterEntityKey;
      var complete = true;
      for (final entry in heads) {
        final remote = peerSummary.heads[entry.key];
        if (remote != null && remote.compareOperation(entry.value) <= 0) {
          cursor = entry.key;
          continue;
        }
        if (envelopes.length == maxOperations) {
          complete = false;
          break;
        }
        final operation = entry.value;
        final envelope = await const E2EESyncCipher().encrypt(
          id: 'mesh-$epoch-${operation.id}',
          deviceId: deviceId,
          vectorClock: operation.vectorClock,
          operations: [operation],
          key: key,
          keyEpoch: epoch,
          createdAt: operation.timestamp,
        );
        final envelopeBytes = utf8
            .encode(jsonEncode(envelope.toRelayBlob()))
            .length;
        if (envelopeBytes > maxEncodedBytes && envelopes.isEmpty) {
          throw StateError(
            'A CRDT winner exceeds the configured mesh chunk byte limit.',
          );
        }
        if (encodedBytes + envelopeBytes > maxEncodedBytes) {
          complete = false;
          break;
        }
        envelopes.add(envelope);
        encodedBytes += envelopeBytes;
        cursor = entry.key;
      }
      return MeshExportPage(
        envelopes: envelopes,
        nextCursor: cursor,
        isComplete: complete,
      ).toJson();
    } finally {
      key.destroy();
    }
  }

  /// Authenticates, decrypts, and LWW-merges serialized peer envelopes.
  ///
  /// Authentication is provided by [E2EESyncCipher]; a modified envelope
  /// fails before any winner is applied. Mesh receipt never marks an outbox
  /// operation delivered, preserving every cloud relay pending row.
  Future<MeshApplyResult> applyAuthenticatedPeerEnvelopes(
    Iterable<Map<String, dynamic>> serializedEnvelopes, {
    required String authenticatedPeerId,
  }) async {
    if (_paused || _syncing || _applyingRemote) {
      throw StateError('Encrypted sync is not available for a peer merge.');
    }
    final envelopes = serializedEnvelopes
        .map(E2EESyncEnvelope.fromRelayBlob)
        .toList(growable: false);
    final epoch = await identity.keyEpoch;
    for (final envelope in envelopes) {
      if (envelope.deviceId != authenticatedPeerId) {
        throw StateError(
          'Peer envelope source does not match the authenticated peer.',
        );
      }
      if (envelope.keyEpoch != epoch) {
        throw StateError('Peer envelope key epoch does not match local epoch.');
      }
    }
    final unseen = envelopes
        .where((envelope) => !outbox.hasSeen(envelope.id))
        .toList(growable: false);
    final key = await identity.requireKey();
    try {
      final applied = await _mergeRemote(unseen, key: key, keyEpoch: epoch);
      return MeshApplyResult(
        receivedEnvelopeCount: envelopes.length,
        appliedWinnerCount: applied,
        duplicateEnvelopeCount: envelopes.length - unseen.length,
      );
    } finally {
      key.destroy();
    }
  }

  void start({
    Stream<bool>? connectivityChanges,
    Duration interval = const Duration(minutes: 5),
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      unawaited(syncNow());
    });
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivityChanges?.listen((online) {
      if (online) unawaited(syncNow());
    });
  }

  Future<CrdtOperation> record({
    required CrdtEntityKind entityKind,
    required String entityId,
    required CrdtMutation mutation,
    Map<String, dynamic> payload = const {},
  }) async {
    if (_paused || _peerReconciling) {
      throw StateError('Encrypted sync writes are temporarily paused.');
    }
    if (_applyingRemote) {
      throw StateError('Remote operations cannot be recorded as local writes.');
    }
    final key = await identity.requireKey();
    try {
      _vectorClock = incrementVectorClock(_vectorClock, deviceId);
      final counter = _vectorClock[deviceId]!;
      final operation = CrdtOperation(
        id: '$deviceId-$counter',
        deviceId: deviceId,
        entityKind: entityKind,
        entityId: entityId,
        mutation: mutation,
        vectorClock: _vectorClock,
        timestamp: _clock(),
        payload: payload,
      );
      await outbox.enqueue(
        operation,
        key: key,
        keyEpoch: await identity.keyEpoch,
      );
      return operation;
    } finally {
      key.destroy();
    }
  }

  Future<void> recordGraphSnapshot(PersonalKnowledgeGraph graph) async {
    if (_applyingRemote || !await identity.isEnabled) return;
    final key = await identity.requireKey();
    late final Map<String, CrdtOperation> heads;
    try {
      heads = await outbox.heads(key: key);
    } finally {
      key.destroy();
    }
    final present = <String>{};
    for (final node in graph.nodes) {
      final entityKey = '${CrdtEntityKind.node.name}:${node.id}';
      present.add(entityKey);
      final payload = _portableNodeJson(node);
      if (heads[entityKey]?.mutation == CrdtMutation.upsert &&
          heads[entityKey]!.payload.toString() == payload.toString()) {
        continue;
      }
      await record(
        entityKind: CrdtEntityKind.node,
        entityId: node.id,
        mutation: CrdtMutation.upsert,
        payload: payload,
      );
    }
    for (final edge in graph.edges) {
      final entityKey = '${CrdtEntityKind.edge.name}:${edge.id}';
      present.add(entityKey);
      if (heads[entityKey]?.mutation == CrdtMutation.upsert &&
          heads[entityKey]!.payload.toString() == edge.toJson().toString()) {
        continue;
      }
      await record(
        entityKind: CrdtEntityKind.edge,
        entityId: edge.id,
        mutation: CrdtMutation.upsert,
        payload: edge.toJson(),
      );
    }
    for (final entry in heads.entries) {
      final operation = entry.value;
      if (present.contains(entry.key) ||
          operation.mutation == CrdtMutation.delete ||
          (operation.entityKind != CrdtEntityKind.node &&
              operation.entityKind != CrdtEntityKind.edge)) {
        continue;
      }
      await record(
        entityKind: operation.entityKind,
        entityId: operation.entityId,
        mutation: CrdtMutation.delete,
      );
    }
  }

  Future<void> recordTranscripts(Iterable<JournalEntry> entries) async {
    if (_applyingRemote || !await identity.isEnabled) return;
    final key = await identity.requireKey();
    late final Map<String, CrdtOperation> heads;
    try {
      heads = await outbox.heads(key: key);
    } finally {
      key.destroy();
    }
    for (final entry in entries) {
      final payload = entry.toJson(includeLocalContext: false)
        ..remove('localAudioPath')
        ..remove('localAudioVaultRef')
        ..['mediaAttachments'] = entry.mediaAttachments
            .map((attachment) => attachment.toPortableJson())
            .toList(growable: false);
      final entityKey = '${CrdtEntityKind.transcript.name}:${entry.id}';
      if (heads[entityKey]?.mutation == CrdtMutation.upsert &&
          heads[entityKey]!.payload.toString() == payload.toString()) {
        continue;
      }
      await record(
        entityKind: CrdtEntityKind.transcript,
        entityId: entry.id,
        mutation: CrdtMutation.upsert,
        payload: payload,
      );
    }
  }

  /// Records a portable semantic-cluster snapshot.
  ///
  /// Membership IDs and user-authored model fields are synchronized, while
  /// graph labels, evidence, transcripts, and local paths are never included.
  Future<List<CrdtOperation>> recordSemanticClusters(
    Iterable<SemanticCluster> clusters,
  ) async {
    if (_applyingRemote || !await identity.isEnabled) return const [];
    final key = await identity.requireKey();
    late final Map<String, CrdtOperation> heads;
    try {
      heads = await outbox.heads(key: key);
    } finally {
      key.destroy();
    }

    final present = <String>{};
    final recorded = <CrdtOperation>[];
    for (final cluster in clusters) {
      final entityKey = '${CrdtEntityKind.semanticCluster.name}:${cluster.id}';
      present.add(entityKey);
      final payload = _portableSemanticClusterJson(cluster);
      if (heads[entityKey]?.mutation == CrdtMutation.upsert &&
          heads[entityKey]!.payload.toString() == payload.toString()) {
        continue;
      }
      recorded.add(
        await record(
          entityKind: CrdtEntityKind.semanticCluster,
          entityId: cluster.id,
          mutation: CrdtMutation.upsert,
          payload: payload,
        ),
      );
    }

    for (final entry in heads.entries) {
      final operation = entry.value;
      if (operation.entityKind != CrdtEntityKind.semanticCluster ||
          present.contains(entry.key) ||
          operation.mutation == CrdtMutation.delete) {
        continue;
      }
      recorded.add(
        await record(
          entityKind: CrdtEntityKind.semanticCluster,
          entityId: operation.entityId,
          mutation: CrdtMutation.delete,
        ),
      );
    }
    return List.unmodifiable(recorded);
  }

  /// Records complete action-plan snapshots. Step completion history remains
  /// inside the encrypted CRDT envelope and is never exposed to the relay.
  Future<List<CrdtOperation>> recordActionPlans(
    Iterable<ActionPlan> plans,
  ) async {
    if (_applyingRemote || !await identity.isEnabled) return const [];
    final key = await identity.requireKey();
    late final Map<String, CrdtOperation> heads;
    try {
      heads = await outbox.heads(key: key);
    } finally {
      key.destroy();
    }
    final present = <String>{};
    final recorded = <CrdtOperation>[];
    for (final plan in plans) {
      final entityKey = '${CrdtEntityKind.actionPlan.name}:${plan.id}';
      present.add(entityKey);
      final payload = plan.toPortableJson();
      if (heads[entityKey]?.mutation == CrdtMutation.upsert &&
          heads[entityKey]!.payload.toString() == payload.toString()) {
        continue;
      }
      recorded.add(
        await record(
          entityKind: CrdtEntityKind.actionPlan,
          entityId: plan.id,
          mutation: CrdtMutation.upsert,
          payload: payload,
        ),
      );
    }
    for (final entry in heads.entries) {
      final operation = entry.value;
      if (operation.entityKind != CrdtEntityKind.actionPlan ||
          present.contains(entry.key) ||
          operation.mutation == CrdtMutation.delete) {
        continue;
      }
      recorded.add(
        await record(
          entityKind: CrdtEntityKind.actionPlan,
          entityId: operation.entityId,
          mutation: CrdtMutation.delete,
        ),
      );
    }
    return List.unmodifiable(recorded);
  }

  Future<void> syncNow() async {
    if (_syncing || _paused || _peerReconciling) return;
    if (!await identity.isEnabled) {
      _emit(EncryptedSyncState.disabled);
      return;
    }
    if (!await _isOnline()) {
      _emit(EncryptedSyncState.offline);
      return;
    }
    _syncing = true;
    _emit(EncryptedSyncState.syncing);
    final key = await identity.requireKey();
    try {
      final epoch = await identity.keyEpoch;
      final pending = await outbox.pending(
        key: key,
        limit: maxPendingOperationsPerSync,
      );
      final batches = _relayBatches(pending);
      for (var index = 0; index < batches.length; index++) {
        final batch = batches[index];
        final batchClock = _mergedClock(batch.map((item) => item.vectorClock));
        final baseId = 'crdt-$deviceId-${batchClock[deviceId] ?? 0}';
        final envelope = await const E2EESyncCipher().encrypt(
          id: batches.length == 1 ? baseId : '$baseId-$index',
          deviceId: deviceId,
          vectorClock: batchClock,
          operations: batch,
          key: key,
          keyEpoch: epoch,
          createdAt: _clock(),
        );
        await transport.push(envelope);
        outbox.markDelivered(batch.map((item) => item.id));
      }

      final unseen = (await transport.pull())
          .where(
            (item) =>
                item.keyEpoch == epoch &&
                !outbox.hasSeen(item.id) &&
                item.deviceId != deviceId,
          )
          .toList();
      if (unseen.isNotEmpty) {
        await _mergeRemote(unseen, key: key, keyEpoch: epoch);
      }
      _devices[deviceId] = SyncDevice(
        id: deviceId,
        lastSeenAt: _clock().toUtc(),
        isCurrentDevice: true,
        keyEpoch: epoch,
      );
      _emit(EncryptedSyncState.upToDate);
    } catch (_) {
      _emit(EncryptedSyncState.error);
      rethrow;
    } finally {
      key.destroy();
      _syncing = false;
    }
  }

  static List<List<CrdtOperation>> _relayBatches(
    List<CrdtOperation> operations,
  ) {
    final result = <List<CrdtOperation>>[];
    var current = <CrdtOperation>[];
    var currentBytes = 2;
    for (final operation in operations) {
      final bytes = utf8.encode(jsonEncode(operation.toJson())).length + 1;
      if (bytes > maxRelayBatchCleartextBytes) {
        throw StateError('A CRDT operation exceeds the relay chunk limit.');
      }
      if (current.isNotEmpty &&
          (current.length >= maxRelayBatchOperations ||
              currentBytes + bytes > maxRelayBatchCleartextBytes)) {
        result.add(List.unmodifiable(current));
        current = <CrdtOperation>[];
        currentBytes = 2;
      }
      current.add(operation);
      currentBytes += bytes;
    }
    if (current.isNotEmpty) result.add(List.unmodifiable(current));
    return List.unmodifiable(result);
  }

  Future<String> revokeDevice(String revokedDeviceId) async {
    if (revokedDeviceId == deviceId) {
      throw ArgumentError('The current device cannot revoke itself.');
    }
    final phrase = await identity.rotate();
    outbox.clear();
    _devices.remove(revokedDeviceId);
    _vectorClock = {};
    await recordGraphSnapshot(await graphStore.load());
    return phrase;
  }

  Future<String> rotateSyncMasterKey() async {
    if (_syncing || _applyingRemote) {
      throw StateError('Wait for the active sync operation to finish.');
    }
    final phrase = await identity.rotate();
    outbox.clear();
    _vectorClock = {};
    await recordGraphSnapshot(await graphStore.load());
    return phrase;
  }

  Future<int> _mergeRemote(
    List<E2EESyncEnvelope> envelopes, {
    required SyncEncryptionKey key,
    required int keyEpoch,
  }) async {
    final heads = await outbox.heads(key: key);
    final winners = <String, CrdtOperation>{};
    for (final envelope in envelopes) {
      final operations = await const E2EESyncCipher().decrypt(
        envelope,
        key: key,
      );
      for (final operation in operations) {
        final entityKey = '${operation.entityKind.name}:${operation.entityId}';
        final current = winners[entityKey] ?? heads[entityKey];
        if (current == null || CrdtOperation.compare(operation, current) > 0) {
          winners[entityKey] = operation;
        }
        _vectorClock = _mergedClock([_vectorClock, operation.vectorClock]);
      }
      _devices[envelope.deviceId] = SyncDevice(
        id: envelope.deviceId,
        lastSeenAt: envelope.createdAt,
        isCurrentDevice: false,
        keyEpoch: envelope.keyEpoch,
      );
    }
    if (winners.isEmpty) {
      for (final envelope in envelopes) {
        outbox.markSeen(envelope.id, at: _clock());
      }
      return 0;
    }

    final graphOperations = winners.values
        .where(
          (item) =>
              item.entityKind == CrdtEntityKind.node ||
              item.entityKind == CrdtEntityKind.edge ||
              item.entityKind == CrdtEntityKind.confidence,
        )
        .toList();
    _applyingRemote = true;
    try {
      if (graphOperations.isNotEmpty) {
        final graph = await graphStore.load();
        final mergedJson = await Isolate.run(
          () => _mergeGraphJson(
            graph.toJson(),
            graphOperations.map((item) => item.toJson()).toList(),
          ),
        );
        final merged = PersonalKnowledgeGraph.fromJson(mergedJson);
        await graphStore.save(merged);
        await semanticStore.saveManualGraph(
          PersonalKnowledgeGraph(
            nodes: merged.nodes.where(
              (node) => node.origin == NodeOrigin.manual,
            ),
            edges: merged.edges.where(
              (edge) => edge.origin == NodeOrigin.manual,
            ),
          ),
        );
        await semanticStore.saveExternalGraph(
          PersonalKnowledgeGraph(
            nodes: merged.nodes.where(
              (node) => node.origin == NodeOrigin.external,
            ),
            edges: merged.edges.where(
              (edge) => edge.origin == NodeOrigin.external,
            ),
          ),
        );
      }
      for (final operation in winners.values) {
        await outbox.putHead(operation, key: key, keyEpoch: keyEpoch);
        if (operation.entityKind == CrdtEntityKind.transcript ||
            operation.entityKind == CrdtEntityKind.node ||
            operation.entityKind == CrdtEntityKind.semanticCluster ||
            operation.entityKind == CrdtEntityKind.actionPlan ||
            operation.entityKind == CrdtEntityKind.mediaManifest ||
            operation.entityKind == CrdtEntityKind.mediaChunk) {
          await _applyAuxiliaryOperation?.call(operation);
        }
      }
      for (final envelope in envelopes) {
        outbox.markSeen(envelope.id, at: _clock());
      }
    } finally {
      _applyingRemote = false;
    }
    return winners.length;
  }

  void _emit(EncryptedSyncState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> dispose() async {
    _periodicTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _states.close();
  }
}

Map<String, dynamic> _portableNodeJson(GraphNode node) {
  final payload = node.toJson();
  payload['mediaAttachments'] = node.mediaAttachments
      .map((attachment) => attachment.toPortableJson())
      .toList(growable: false);
  return payload;
}

Map<String, dynamic> _portableSemanticClusterJson(SemanticCluster cluster) => {
  'id': cluster.id,
  'title': cluster.title,
  'category': cluster.category.wireName,
  'nodeIds': cluster.nodeIds,
  'activityVelocity': cluster.activityVelocity,
  'confidenceScore': cluster.confidenceScore,
  'summary': cluster.summary,
  'pinned': cluster.pinned,
  'updatedAt': cluster.updatedAt.toIso8601String(),
  'userEdited': cluster.userEdited,
};

Map<String, dynamic> _mergeGraphJson(
  Map<String, dynamic> graphJson,
  List<Map<String, dynamic>> operationJson,
) {
  final graph = PersonalKnowledgeGraph.fromJson(graphJson);
  final nodes = {for (final node in graph.nodes) node.id: node};
  final edges = {for (final edge in graph.edges) edge.id: edge};
  for (final raw in operationJson) {
    final operation = CrdtOperation.fromJson(raw);
    switch (operation.entityKind) {
      case CrdtEntityKind.node:
        if (operation.mutation == CrdtMutation.delete) {
          nodes.remove(operation.entityId);
          edges.removeWhere(
            (_, edge) =>
                edge.sourceNodeId == operation.entityId ||
                edge.targetNodeId == operation.entityId,
          );
        } else {
          nodes[operation.entityId] = GraphNode.fromJson(operation.payload);
        }
        continue;
      case CrdtEntityKind.edge:
        if (operation.mutation == CrdtMutation.delete) {
          edges.remove(operation.entityId);
        } else {
          edges[operation.entityId] = GraphEdge.fromJson(operation.payload);
        }
        continue;
      case CrdtEntityKind.confidence:
        final node = nodes[operation.entityId];
        final confidence = operation.payload['confidence'] as num?;
        if (node != null && confidence != null) {
          nodes[node.id] = GraphNode(
            id: node.id,
            type: node.type,
            label: node.label,
            confidence: confidence,
            evidence: node.evidence,
            origin: node.origin,
            createdAt: node.createdAt,
            archivedAt: node.archivedAt,
            theoryId: node.theoryId,
            externalSource: node.externalSource,
            tags: node.tags,
          );
        }
        continue;
      case CrdtEntityKind.transcript:
      case CrdtEntityKind.semanticCluster:
      case CrdtEntityKind.actionPlan:
      case CrdtEntityKind.mediaManifest:
      case CrdtEntityKind.mediaChunk:
        continue;
    }
  }
  final nodeIds = nodes.keys.toSet();
  return PersonalKnowledgeGraph(
    schemaVersion: graph.schemaVersion,
    nodes: nodes.values,
    edges: edges.values.where(
      (edge) =>
          nodeIds.contains(edge.sourceNodeId) &&
          nodeIds.contains(edge.targetNodeId),
    ),
    trajectories: graph.trajectories.where(
      (trajectory) =>
          nodeIds.contains(trajectory.subjectNodeId) &&
          (trajectory.relatedNodeId == null ||
              nodeIds.contains(trajectory.relatedNodeId)),
    ),
    materialization: graph.materialization,
  ).toJson();
}

Map<String, int> _mergedClock(Iterable<Map<String, int>> clocks) {
  final result = <String, int>{};
  for (final clock in clocks) {
    for (final item in clock.entries) {
      if ((result[item.key] ?? 0) < item.value) result[item.key] = item.value;
    }
  }
  return Map.unmodifiable(result);
}
