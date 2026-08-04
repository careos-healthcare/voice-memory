// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import '../../core/graph/graph_node.dart';
import '../../storage/encrypted_json_file_store.dart';

final class DocumentCitation {
  const DocumentCitation({
    required this.id,
    required this.documentId,
    required this.nodeId,
    required this.recordId,
    required this.startChar,
    required this.endChar,
    required this.excerpt,
  });

  final String id;
  final String documentId;
  final String nodeId;
  final String recordId;
  final int startChar;
  final int endChar;
  final String excerpt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'nodeId': nodeId,
    'recordId': recordId,
    'startChar': startChar,
    'endChar': endChar,
    'excerpt': excerpt,
  };

  factory DocumentCitation.fromJson(Map<String, dynamic> json) =>
      DocumentCitation(
        id: json['id'] as String,
        documentId: json['documentId'] as String,
        nodeId: json['nodeId'] as String,
        recordId: json['recordId'] as String,
        startChar: (json['startChar'] as num).toInt(),
        endChar: (json['endChar'] as num).toInt(),
        excerpt: json['excerpt'] as String,
      );
}

final class DocumentClusterAttribution {
  const DocumentClusterAttribution({
    required this.id,
    required this.documentId,
    required this.recordId,
    required this.clusterId,
    required this.score,
  });

  final String id;
  final String documentId;
  final String recordId;
  final String clusterId;
  final double score;

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'recordId': recordId,
    'clusterId': clusterId,
    'score': score,
  };

  factory DocumentClusterAttribution.fromJson(Map<String, dynamic> json) =>
      DocumentClusterAttribution(
        id: json['id'] as String,
        documentId: json['documentId'] as String,
        recordId: json['recordId'] as String,
        clusterId: json['clusterId'] as String,
        score: (json['score'] as num).toDouble(),
      );
}

final class DocumentOverlayTombstone {
  const DocumentOverlayTombstone({
    required this.documentId,
    required this.deletedAt,
    required this.reason,
  });

  final String documentId;
  final DateTime deletedAt;
  final String reason;

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'deletedAt': deletedAt.toUtc().toIso8601String(),
    'reason': reason,
  };

  factory DocumentOverlayTombstone.fromJson(Map<String, dynamic> json) =>
      DocumentOverlayTombstone(
        documentId: json['documentId'] as String,
        deletedAt: DateTime.parse(json['deletedAt'] as String).toUtc(),
        reason: json['reason'] as String,
      );
}

final class DocumentGraphOverlaySnapshot {
  DocumentGraphOverlaySnapshot({
    required Iterable<GraphNode> nodes,
    required Iterable<GraphEdge> edges,
    required Iterable<DocumentCitation> citations,
    required Iterable<DocumentClusterAttribution> attributions,
    required Iterable<DocumentOverlayTombstone> tombstones,
    required this.revision,
  }) : nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(edges),
       citations = List.unmodifiable(citations),
       attributions = List.unmodifiable(attributions),
       tombstones = List.unmodifiable(tombstones);

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<DocumentCitation> citations;
  final List<DocumentClusterAttribution> attributions;
  final List<DocumentOverlayTombstone> tombstones;
  final int revision;
}

/// Encrypted document graph overlay, isolated from the personal graph store.
final class DocumentGraphOverlayStore {
  DocumentGraphOverlayStore({
    required EncryptedJsonFileStore storage,
    DateTime Function()? clock,
  }) : _storage = storage,
       _clock = clock ?? DateTime.now;

  static const int schemaVersion = 1;

  final EncryptedJsonFileStore _storage;
  final DateTime Function() _clock;
  final StreamController<int> _revisionController =
      StreamController<int>.broadcast();
  Future<void> _writeTail = Future<void>.value();
  int _revision = 0;

  int get revision => _revision;
  Stream<int> get revisions => _revisionController.stream;
  Stream<int> get revisionStream => revisions;

  Future<DocumentGraphOverlaySnapshot> load() async {
    await _writeTail.catchError((Object _) {});
    final snapshot = await _read();
    _revision = snapshot.revision;
    return snapshot;
  }

  Future<void> replaceDocument({
    required String documentId,
    required Iterable<GraphNode> nodes,
    required Iterable<GraphEdge> edges,
    required Iterable<DocumentCitation> citations,
    required Iterable<DocumentClusterAttribution> attributions,
  }) => _serialized(() async {
    final replacementNodes = nodes.toList();
    final replacementEdges = edges.toList();
    if (replacementNodes.any((node) => node.origin != NodeOrigin.document) ||
        replacementEdges.any((edge) => edge.origin != NodeOrigin.document)) {
      throw ArgumentError(
        'Document overlay entities must use document origin.',
      );
    }
    final current = await _read();
    final next = DocumentGraphOverlaySnapshot(
      nodes: [
        ...current.nodes.where((item) => !_belongsTo(item.id, documentId)),
        ...replacementNodes,
      ],
      edges: [
        ...current.edges.where((item) => !_belongsTo(item.id, documentId)),
        ...replacementEdges,
      ],
      citations: [
        ...current.citations.where((item) => item.documentId != documentId),
        ...citations,
      ],
      attributions: [
        ...current.attributions.where((item) => item.documentId != documentId),
        ...attributions,
      ],
      tombstones: current.tombstones.where(
        (item) => item.documentId != documentId,
      ),
      revision: current.revision + 1,
    );
    await _write(next);
    _changed(next.revision);
  });

  Future<void> removeDocument(
    String documentId, {
    String reason = 'removed',
  }) => _serialized(() async {
    final current = await _read();
    final next = DocumentGraphOverlaySnapshot(
      nodes: current.nodes.where((item) => !_belongsTo(item.id, documentId)),
      edges: current.edges.where((item) => !_belongsTo(item.id, documentId)),
      citations: current.citations.where(
        (item) => item.documentId != documentId,
      ),
      attributions: current.attributions.where(
        (item) => item.documentId != documentId,
      ),
      tombstones: [
        ...current.tombstones.where((item) => item.documentId != documentId),
        DocumentOverlayTombstone(
          documentId: documentId,
          deletedAt: _clock().toUtc(),
          reason: reason,
        ),
      ],
      revision: current.revision + 1,
    );
    await _write(next);
    _changed(next.revision);
  });

  Future<void> rollbackDocument(String documentId) =>
      removeDocument(documentId, reason: 'rollback');

  Future<DocumentGraphOverlaySnapshot> _read() async {
    final raw = await _storage.readJson();
    if (raw == null) {
      return DocumentGraphOverlaySnapshot(
        nodes: const [],
        edges: const [],
        citations: const [],
        attributions: const [],
        tombstones: const [],
        revision: 0,
      );
    }
    if (raw is! Map || raw['schemaVersion'] != schemaVersion) {
      throw const FormatException('Invalid document graph overlay.');
    }
    return DocumentGraphOverlaySnapshot(
      nodes: _rows(raw['nodes']).map(GraphNode.fromJson),
      edges: _rows(raw['edges']).map(GraphEdge.fromJson),
      citations: _rows(raw['citations']).map(DocumentCitation.fromJson),
      attributions: _rows(
        raw['attributions'],
      ).map(DocumentClusterAttribution.fromJson),
      tombstones: _rows(
        raw['tombstones'],
      ).map(DocumentOverlayTombstone.fromJson),
      revision: (raw['revision'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _write(DocumentGraphOverlaySnapshot snapshot) {
    final nodes = snapshot.nodes.toList()..sort((a, b) => a.id.compareTo(b.id));
    final edges = snapshot.edges.toList()..sort((a, b) => a.id.compareTo(b.id));
    final citations = snapshot.citations.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final attributions = snapshot.attributions.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final tombstones = snapshot.tombstones.toList()
      ..sort((a, b) => a.documentId.compareTo(b.documentId));
    return _storage.writeJson({
      'schemaVersion': schemaVersion,
      'revision': snapshot.revision,
      'nodes': nodes.map((item) => item.toJson()).toList(),
      'edges': edges.map((item) => item.toJson()).toList(),
      'citations': citations.map((item) => item.toJson()).toList(),
      'attributions': attributions.map((item) => item.toJson()).toList(),
      'tombstones': tombstones.map((item) => item.toJson()).toList(),
    });
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _changed(int nextRevision) {
    _revision = nextRevision;
    _revisionController.add(nextRevision);
  }

  Future<void> dispose() async {
    await _writeTail.catchError((Object _) {});
    await _revisionController.close();
  }

  static bool _belongsTo(String id, String documentId) =>
      id.startsWith('document:$documentId:');

  static Iterable<Map<String, dynamic>> _rows(Object? value) sync* {
    if (value is! List) return;
    for (final row in value.whereType<Map>()) {
      yield Map<String, dynamic>.from(row);
    }
  }
}
