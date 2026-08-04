import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../models/journal_sync_metadata.dart' as canonical;
import '../local_storage/encrypted_sqlite_text_codec.dart';

enum MeshCrdtEntityKind { graphNode, graphEdge, vectorMetadata }

typedef MeshVectorClockRelation = canonical.VectorClockRelation;

final class MeshCrdtDelta {
  MeshCrdtDelta({
    required this.operationId,
    required this.entityId,
    required this.kind,
    required this.deviceId,
    required Map<String, int> vectorClock,
    required DateTime updatedAt,
    required this.payload,
    this.tombstone = false,
  }) : vectorClock = Map.unmodifiable(vectorClock),
       updatedAt = updatedAt.toUtc() {
    if (operationId.isEmpty || entityId.isEmpty || deviceId.isEmpty) {
      throw ArgumentError('CRDT identifiers must not be empty.');
    }
    if (vectorClock.values.any((value) => value < 0)) {
      throw ArgumentError('Vector clock counters must be non-negative.');
    }
    if (!tombstone && payload == null) {
      throw ArgumentError('A live CRDT element requires a payload.');
    }
  }

  final String operationId;
  final String entityId;
  final MeshCrdtEntityKind kind;
  final String deviceId;
  final Map<String, int> vectorClock;
  final DateTime updatedAt;
  final Map<String, dynamic>? payload;
  final bool tombstone;

  String get entityKey => '${kind.name}:$entityId';

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'entityId': entityId,
    'kind': kind.name,
    'deviceId': deviceId,
    'vectorClock': vectorClock,
    'updatedAt': updatedAt.toIso8601String(),
    'payload': payload,
    'tombstone': tombstone,
  };

  factory MeshCrdtDelta.fromJson(Map<String, dynamic> json) => MeshCrdtDelta(
    operationId: '${json['operationId']}',
    entityId: '${json['entityId']}',
    kind: MeshCrdtEntityKind.values.byName('${json['kind']}'),
    deviceId: '${json['deviceId']}',
    vectorClock: {
      for (final entry in (json['vectorClock'] as Map? ?? const {}).entries)
        if (entry.value is num) '${entry.key}': (entry.value as num).toInt(),
    },
    updatedAt:
        DateTime.tryParse('${json['updatedAt']}') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : null,
    tombstone: json['tombstone'] == true,
  );
}

final class MeshReconcileResult {
  const MeshReconcileResult({
    required this.received,
    required this.applied,
    required this.ignored,
  });

  final int received;
  final int applied;
  final int ignored;
}

final class SqliteMeshCrdtStore {
  factory SqliteMeshCrdtStore({
    required Database database,
    required EncryptedSqliteTextCodec codec,
    bool ownsDatabase = false,
  }) => SqliteMeshCrdtStore._(database, codec, ownsDatabase);

  SqliteMeshCrdtStore._(this._database, this.codec, this.ownsDatabase) {
    _database.execute('''
      CREATE TABLE IF NOT EXISTS sovereign_mesh_crdt (
        record_key TEXT PRIMARY KEY,
        encrypted_delta TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<SqliteMeshCrdtStore> open({
    required String databasePath,
    required EncryptedSqliteTextCodec codec,
  }) async {
    await Directory(path.dirname(databasePath)).create(recursive: true);
    final database = sqlite3.open(databasePath)
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('PRAGMA synchronous = NORMAL')
      ..execute('PRAGMA busy_timeout = 3000');
    return SqliteMeshCrdtStore(
      database: database,
      codec: codec,
      ownsDatabase: true,
    );
  }

  final Database _database;
  final EncryptedSqliteTextCodec codec;
  final bool ownsDatabase;

  List<MeshCrdtDelta> readAll() => _database
      .select(
        'SELECT encrypted_delta FROM sovereign_mesh_crdt '
        'ORDER BY record_key',
      )
      .map((row) {
        final cleartext = codec.decode(row['encrypted_delta'] as String);
        final decoded = jsonDecode(cleartext ?? '');
        if (decoded is! Map) {
          throw const FormatException('Invalid encrypted mesh CRDT row.');
        }
        return MeshCrdtDelta.fromJson(Map<String, dynamic>.from(decoded));
      })
      .toList(growable: false);

  void upsert(MeshCrdtDelta delta) {
    final encoded = codec.encode(jsonEncode(delta.toJson()));
    _database.execute(
      'INSERT OR REPLACE INTO sovereign_mesh_crdt('
      'record_key, encrypted_delta, updated_at) VALUES (?, ?, ?)',
      [
        sha256.convert(utf8.encode(delta.entityKey)).toString(),
        encoded,
        delta.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  void close() {
    if (ownsDatabase) _database.close();
  }
}

final class MeshStateReconciler {
  MeshStateReconciler({
    required this.deviceId,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _heads.addEntries(
      store.readAll().map((item) => MapEntry(item.entityKey, item)),
    );
  }

  final String deviceId;
  final SqliteMeshCrdtStore store;
  final DateTime Function() _clock;
  final Map<String, MeshCrdtDelta> _heads = {};

  List<MeshCrdtDelta> get heads {
    final values = _heads.values.toList()
      ..sort((left, right) => left.entityKey.compareTo(right.entityKey));
    return List.unmodifiable(values);
  }

  MeshCrdtDelta write({
    required MeshCrdtEntityKind kind,
    required String entityId,
    required Map<String, dynamic> payload,
  }) => _write(kind: kind, entityId: entityId, payload: payload);

  MeshCrdtDelta remove({
    required MeshCrdtEntityKind kind,
    required String entityId,
  }) => _write(kind: kind, entityId: entityId, tombstone: true);

  void captureGraphSnapshot(PersonalKnowledgeGraph graph) {
    final liveKeys = <String>{};
    for (final node in graph.nodes) {
      liveKeys.add('${MeshCrdtEntityKind.graphNode.name}:${node.id}');
      _writeIfChanged(
        kind: MeshCrdtEntityKind.graphNode,
        entityId: node.id,
        payload: node.toJson(),
      );
    }
    for (final edge in graph.edges) {
      liveKeys.add('${MeshCrdtEntityKind.graphEdge.name}:${edge.id}');
      _writeIfChanged(
        kind: MeshCrdtEntityKind.graphEdge,
        entityId: edge.id,
        payload: edge.toJson(),
      );
    }
    for (final current in heads.where(
      (delta) =>
          delta.kind != MeshCrdtEntityKind.vectorMetadata &&
          !delta.tombstone &&
          !liveKeys.contains(delta.entityKey),
    )) {
      remove(kind: current.kind, entityId: current.entityId);
    }
  }

  void captureVectorMetadata(String entryId, Map<String, dynamic> metadata) =>
      _writeIfChanged(
        kind: MeshCrdtEntityKind.vectorMetadata,
        entityId: entryId,
        payload: metadata,
      );

  void _writeIfChanged({
    required MeshCrdtEntityKind kind,
    required String entityId,
    required Map<String, dynamic> payload,
  }) {
    final current = _heads['${kind.name}:$entityId'];
    if (current != null &&
        !current.tombstone &&
        jsonEncode(current.payload) == jsonEncode(payload)) {
      return;
    }
    write(kind: kind, entityId: entityId, payload: payload);
  }

  MeshCrdtDelta _write({
    required MeshCrdtEntityKind kind,
    required String entityId,
    Map<String, dynamic>? payload,
    bool tombstone = false,
  }) {
    final key = '${kind.name}:$entityId';
    final clock = Map<String, int>.from(_heads[key]?.vectorClock ?? const {});
    final counter = (clock[deviceId] ?? 0) + 1;
    clock[deviceId] = counter;
    final delta = MeshCrdtDelta(
      operationId: '$deviceId:$counter:$key',
      entityId: entityId,
      kind: kind,
      deviceId: deviceId,
      vectorClock: clock,
      updatedAt: _clock(),
      payload: payload,
      tombstone: tombstone,
    );
    _heads[key] = delta;
    store.upsert(delta);
    return delta;
  }

  MeshReconcileResult merge(Iterable<MeshCrdtDelta> incoming) {
    var applied = 0;
    var ignored = 0;
    final values = incoming.toList()
      ..sort((left, right) {
        final key = left.entityKey.compareTo(right.entityKey);
        return key != 0 ? key : left.operationId.compareTo(right.operationId);
      });
    for (final candidate in values) {
      final current = _heads[candidate.entityKey];
      if (current == null || compare(candidate, current) > 0) {
        _heads[candidate.entityKey] = candidate;
        store.upsert(candidate);
        applied++;
      } else {
        ignored++;
      }
    }
    return MeshReconcileResult(
      received: values.length,
      applied: applied,
      ignored: ignored,
    );
  }

  List<MeshCrdtDelta> deltaSince(Map<String, int> peerClock) =>
      List.unmodifiable(
        heads.where(
          (delta) => delta.vectorClock.entries.any(
            (entry) => entry.value > (peerClock[entry.key] ?? 0),
          ),
        ),
      );

  Map<String, int> aggregateClock() {
    final result = <String, int>{};
    for (final delta in _heads.values) {
      for (final entry in delta.vectorClock.entries) {
        if (entry.value > (result[entry.key] ?? 0)) {
          result[entry.key] = entry.value;
        }
      }
    }
    return Map.unmodifiable(result);
  }

  Future<void> materializeGraph(PersonalKnowledgeGraphStore graphStore) async {
    await graphStore.update((graph) {
      final nodes = {for (final node in graph.nodes) node.id: node};
      final edges = {for (final edge in graph.edges) edge.id: edge};
      for (final delta in heads) {
        switch (delta.kind) {
          case MeshCrdtEntityKind.graphNode:
            if (delta.tombstone) {
              nodes.remove(delta.entityId);
              edges.removeWhere(
                (_, edge) =>
                    edge.sourceNodeId == delta.entityId ||
                    edge.targetNodeId == delta.entityId,
              );
            } else {
              nodes[delta.entityId] = GraphNode.fromJson(delta.payload!);
            }
          case MeshCrdtEntityKind.graphEdge:
            if (delta.tombstone) {
              edges.remove(delta.entityId);
            } else {
              edges[delta.entityId] = GraphEdge.fromJson(delta.payload!);
            }
          case MeshCrdtEntityKind.vectorMetadata:
            break;
        }
      }
      edges.removeWhere(
        (_, edge) =>
            !nodes.containsKey(edge.sourceNodeId) ||
            !nodes.containsKey(edge.targetNodeId),
      );
      return PersonalKnowledgeGraph(
        schemaVersion: graph.schemaVersion,
        nodes: nodes.values,
        edges: edges.values,
        trajectories: graph.trajectories,
        materialization: graph.materialization,
        clock: graph.clock,
      );
    });
  }

  List<Map<String, dynamic>> vectorMetadata() => heads
      .where(
        (delta) =>
            delta.kind == MeshCrdtEntityKind.vectorMetadata && !delta.tombstone,
      )
      .map((delta) => Map<String, dynamic>.from(delta.payload!))
      .toList(growable: false);

  static int compare(MeshCrdtDelta candidate, MeshCrdtDelta current) {
    final relation = compareVectorClocks(
      candidate.vectorClock,
      current.vectorClock,
    );
    switch (relation) {
      case MeshVectorClockRelation.dominates:
        return 1;
      case MeshVectorClockRelation.isDominated:
        return -1;
      case MeshVectorClockRelation.equal:
      case MeshVectorClockRelation.concurrent:
        final time = candidate.updatedAt.compareTo(current.updatedAt);
        if (time != 0) return time;
        final device = candidate.deviceId.compareTo(current.deviceId);
        if (device != 0) return device;
        return candidate.operationId.compareTo(current.operationId);
    }
  }
}

MeshVectorClockRelation compareVectorClocks(
  Map<String, int> left,
  Map<String, int> right,
) => canonical.compareVectorClocks(left, right);
