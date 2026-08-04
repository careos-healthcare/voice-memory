import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../storage/private_data_encryption_key_store.dart';
import 'horizon_models.dart';

final class HorizonLabService {
  HorizonLabService._(
    this._database,
    this._keyStore,
    this.primaryGraphStore,
    this._clock,
  );

  final Database _database;
  final PrivateDataEncryptionKeyStore _keyStore;
  final PersonalKnowledgeGraphStore primaryGraphStore;
  final DateTime Function() _clock;
  final AesGcm _aes = AesGcm.with256bits();
  final StreamController<int> _revisions = StreamController<int>.broadcast(
    sync: true,
  );
  Future<void> _tail = Future<void>.value();
  int _revision = 0;
  bool _closed = false;

  Stream<int> get revisions => _revisions.stream;
  int get revision => _revision;

  static HorizonLabService open({
    required String databasePath,
    required PrivateDataEncryptionKeyStore keyStore,
    required PersonalKnowledgeGraphStore primaryGraphStore,
    DateTime Function()? clock,
  }) {
    Directory(databasePath).parent.createSync(recursive: true);
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = FULL')
      ..execute('PRAGMA secure_delete = ON')
      ..execute('PRAGMA busy_timeout = 3000')
      ..execute('''
        CREATE TABLE IF NOT EXISTS horizon_branches (
          id TEXT PRIMARY KEY,
          name BLOB NOT NULL,
          name_nonce BLOB NOT NULL,
          name_mac BLOB NOT NULL,
          parent_branch_id TEXT,
          divergence_node_id TEXT NOT NULL,
          status TEXT NOT NULL,
          payload BLOB NOT NULL,
          payload_nonce BLOB NOT NULL,
          payload_mac BLOB NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''')
      ..execute(
        'CREATE INDEX IF NOT EXISTS horizon_branch_status '
        'ON horizon_branches(status, updated_at DESC)',
      );
    return HorizonLabService._(
      database,
      keyStore,
      primaryGraphStore,
      clock ?? DateTime.now,
    );
  }

  Future<List<TimelineBranch>> list({bool includeArchived = true}) =>
      _serialized(() async {
        _ensureOpen();
        final rows = _database.select(
          'SELECT * FROM horizon_branches '
          '${includeArchived ? '' : "WHERE status != 'archived'"} '
          'ORDER BY updated_at DESC, id ASC',
        );
        return List.unmodifiable([for (final row in rows) await _decode(row)]);
      });

  Future<TimelineBranch?> get(String id) => _serialized(() async {
    final rows = _database.select(
      'SELECT * FROM horizon_branches WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : _decode(rows.single);
  });

  Future<TimelineBranch> fork({
    required String name,
    required String divergenceNodeId,
    String? parentBranchId,
    Iterable<String>? activeNodeIds,
  }) => _serialized(() async {
    _ensureOpen();
    final source = parentBranchId == null
        ? await primaryGraphStore.load()
        : (await _getDirect(parentBranchId))?.overlay;
    if (source == null) {
      throw StateError('The parent timeline branch does not exist.');
    }
    final byId = {for (final node in source.nodes) node.id: node};
    final divergence = byId[divergenceNodeId];
    if (divergence == null || divergence.archivedAt != null) {
      throw ArgumentError.value(
        divergenceNodeId,
        'divergenceNodeId',
        'must reference an active source node',
      );
    }
    final requested =
        (activeNodeIds ??
                source.nodes
                    .where((node) => node.archivedAt == null)
                    .map((node) => node.id))
            .where(byId.containsKey)
            .toSet()
          ..add(divergenceNodeId);
    final orderedIds = requested.toList()..sort();
    if (orderedIds.length > 512) {
      orderedIds
        ..remove(divergenceNodeId)
        ..removeRange(511, orderedIds.length)
        ..add(divergenceNodeId)
        ..sort();
    }
    final selectedIds = orderedIds.toSet();
    final nodes = orderedIds.map((id) => byId[id]!).toList();
    final edges =
        source.edges
            .where(
              (edge) =>
                  edge.archivedAt == null &&
                  selectedIds.contains(edge.sourceNodeId) &&
                  selectedIds.contains(edge.targetNodeId),
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));
    final now = _clock().toUtc();
    final branch = TimelineBranch(
      id: 'horizon_${const Uuid().v4()}',
      name: name,
      parentBranchId: parentBranchId,
      divergenceNodeId: divergenceNodeId,
      status: TimelineBranchStatus.active,
      overlay: PersonalKnowledgeGraph(nodes: nodes, edges: edges),
      forkedNodeIds: selectedIds,
      forkedEdgeIds: edges.map((edge) => edge.id),
      createdAt: now,
      updatedAt: now,
    );
    await _write(branch);
    return branch;
  });

  Future<TimelineBranch> addProjections(
    String branchId,
    Iterable<HorizonProjectedNode> projections,
  ) => _serialized(() async {
    final branch = await _requireActive(branchId);
    final normalized = projections.toList();
    final nodes = {for (final node in branch.overlay.nodes) node.id: node};
    final edges = {for (final edge in branch.overlay.edges) edge.id: edge};
    for (final projection in normalized) {
      final nodeId = stableGraphId('horizon-node', [
        branch.id,
        projection.id,
        projection.horizon.name,
      ]);
      nodes[nodeId] = GraphNode(
        id: nodeId,
        type: projection.type,
        label: projection.label,
        confidence: projection.probability,
        origin: NodeOrigin.horizon,
        createdAt: _clock(),
      );
      final targets = projection.rippleTargetIds
          .where(nodes.containsKey)
          .toSet();
      if (targets.isEmpty) targets.add(branch.divergenceNodeId);
      for (final targetId in targets) {
        final edge = GraphEdge(
          id: stableGraphId('horizon-edge', [branch.id, nodeId, targetId]),
          sourceNodeId: targetId,
          targetNodeId: nodeId,
          type: EdgeType.influences,
          isDirected: true,
          weight: projection.probability,
          origin: NodeOrigin.horizon,
          createdAt: _clock(),
        );
        edges[edge.id] = edge;
      }
    }
    final updated = branch.copyWith(
      overlay: PersonalKnowledgeGraph(nodes: nodes.values, edges: edges.values),
      projections: {
        for (final item in [...branch.projections, ...normalized])
          item.id: item,
      }.values,
      updatedAt: _clock(),
    );
    await _write(updated);
    return updated;
  });

  Future<TimelineBranch> setStatus(String id, TimelineBranchStatus status) =>
      _serialized(() async {
        final branch =
            await _getDirect(id) ??
            (throw StateError('Timeline branch does not exist.'));
        if (branch.status == TimelineBranchStatus.converged &&
            status != TimelineBranchStatus.converged) {
          throw StateError('A converged branch cannot be reactivated.');
        }
        final updated = branch.copyWith(status: status, updatedAt: _clock());
        await _write(updated);
        return updated;
      });

  /// Deterministic, idempotent set-union of projected entities into reality.
  ///
  /// Forked source entities are never copied back, so edits inside an isolated
  /// overlay cannot overwrite newer primary-timeline state.
  Future<PersonalKnowledgeGraph> mergeIntoPrimary(String branchId) =>
      _serialized(() async {
        final branch = await _requireActive(branchId);
        final projectedNodes =
            branch.overlay.nodes
                .where((node) => !branch.forkedNodeIds.contains(node.id))
                .toList()
              ..sort((left, right) => left.id.compareTo(right.id));
        final projectedEdges =
            branch.overlay.edges
                .where((edge) => !branch.forkedEdgeIds.contains(edge.id))
                .toList()
              ..sort((left, right) => left.id.compareTo(right.id));
        final merged = await primaryGraphStore.update((primary) {
          final nodes = {for (final node in primary.nodes) node.id: node};
          for (final node in projectedNodes) {
            nodes.putIfAbsent(node.id, () => node);
          }
          final edges = {for (final edge in primary.edges) edge.id: edge};
          for (final edge in projectedEdges) {
            if (nodes.containsKey(edge.sourceNodeId) &&
                nodes.containsKey(edge.targetNodeId)) {
              edges.putIfAbsent(edge.id, () => edge);
            }
          }
          return PersonalKnowledgeGraph(
            schemaVersion: primary.schemaVersion,
            nodes: nodes.values,
            edges: edges.values,
            trajectories: primary.trajectories,
            materialization: primary.materialization,
            clock: primary.clock,
          );
        });
        await _write(
          branch.copyWith(
            status: TimelineBranchStatus.converged,
            updatedAt: _clock(),
          ),
        );
        return merged;
      });

  Future<void> delete(String id) => _serialized(() async {
    _database.execute('DELETE FROM horizon_branches WHERE id = ?', [id]);
    _notify();
  });

  Future<void> clear() => _serialized(() async {
    _database.execute('DELETE FROM horizon_branches');
    _notify();
  });

  Future<void> checkpoint() => _serialized(() async {
    _ensureOpen();
    _database.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  });

  Future<TimelineBranch> _requireActive(String id) async {
    final branch = await _getDirect(id);
    if (branch == null) throw StateError('Timeline branch does not exist.');
    if (branch.status != TimelineBranchStatus.active) {
      throw StateError('Timeline branch is not active.');
    }
    return branch;
  }

  Future<TimelineBranch?> _getDirect(String id) async {
    final rows = _database.select(
      'SELECT * FROM horizon_branches WHERE id = ?',
      [id],
    );
    return rows.isEmpty ? null : _decode(rows.single);
  }

  Future<void> _write(TimelineBranch branch) async {
    final name = await _encrypt(
      'name|${branch.id}',
      Uint8List.fromList(utf8.encode(branch.name)),
    );
    final payload = await _encrypt(
      'payload|${branch.id}',
      Uint8List.fromList(utf8.encode(jsonEncode(branch.toJson()))),
    );
    _database.execute(
      'INSERT OR REPLACE INTO horizon_branches'
      '(id, name, name_nonce, name_mac, parent_branch_id, divergence_node_id, '
      'status, payload, payload_nonce, payload_mac, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        branch.id,
        name.cipherText,
        name.nonce,
        name.mac,
        branch.parentBranchId,
        branch.divergenceNodeId,
        branch.status.name,
        payload.cipherText,
        payload.nonce,
        payload.mac,
        branch.createdAt.millisecondsSinceEpoch,
        branch.updatedAt.millisecondsSinceEpoch,
      ],
    );
    _notify();
  }

  Future<TimelineBranch> _decode(Row row) async {
    final id = row['id'] as String;
    final clear = await _decrypt(
      'payload|$id',
      row['payload'] as Uint8List,
      row['payload_nonce'] as Uint8List,
      row['payload_mac'] as Uint8List,
    );
    try {
      return TimelineBranch.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map),
      );
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<_Encrypted> _encrypt(String aad, Uint8List clear) async {
    try {
      final box = await _aes.encrypt(
        clear,
        secretKey: SecretKey(await _key()),
        aad: utf8.encode('horizon-v1|$aad'),
      );
      return _Encrypted(
        Uint8List.fromList(box.cipherText),
        Uint8List.fromList(box.nonce),
        Uint8List.fromList(box.mac.bytes),
      );
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<Uint8List> _decrypt(
    String aad,
    Uint8List cipherText,
    Uint8List nonce,
    Uint8List mac,
  ) async => Uint8List.fromList(
    await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(await _key()),
      aad: utf8.encode('horizon-v1|$aad'),
    ),
  );

  Future<List<int>> _key() async {
    final existing = await _keyStore.readKeyBytes();
    if (existing != null && existing.length == 32) return existing;
    final created = await (await _aes.newSecretKey()).extractBytes();
    await _keyStore.writeKeyBytes(created);
    return created;
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _notify() {
    _revision++;
    if (!_revisions.isClosed) _revisions.add(_revision);
  }

  void _ensureOpen() {
    if (_closed) throw StateError('HorizonLabService is closed.');
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _tail.catchError((Object _) {});
    await _revisions.close();
    _database.close();
  }
}

final class _Encrypted {
  const _Encrypted(this.cipherText, this.nonce, this.mac);
  final Uint8List cipherText;
  final Uint8List nonce;
  final Uint8List mac;
}
