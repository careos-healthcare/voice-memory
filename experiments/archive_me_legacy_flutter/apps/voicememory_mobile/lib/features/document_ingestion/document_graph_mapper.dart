import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../features/semantic_clusters/semantic_cluster.dart';
import '../../storage/encrypted_json_file_store.dart';
import 'document_models.dart';
import 'document_semantic_index.dart';

final class DocumentCitation {
  const DocumentCitation({
    required this.documentId,
    required this.chunkIndex,
    required this.startChar,
    required this.endChar,
    required this.pageNumbers,
    required this.chapterIndexes,
  });

  final String documentId;
  final int chunkIndex;
  final int startChar;
  final int endChar;
  final List<int> pageNumbers;
  final List<int> chapterIndexes;

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'chunkIndex': chunkIndex,
    'startChar': startChar,
    'endChar': endChar,
    'pageNumbers': pageNumbers,
    'chapterIndexes': chapterIndexes,
  };

  factory DocumentCitation.fromJson(Map<String, dynamic> json) =>
      DocumentCitation(
        documentId: json['documentId'] as String,
        chunkIndex: (json['chunkIndex'] as num).toInt(),
        startChar: (json['startChar'] as num).toInt(),
        endChar: (json['endChar'] as num).toInt(),
        pageNumbers: (json['pageNumbers'] as List? ?? const [])
            .whereType<num>()
            .map((value) => value.toInt())
            .toList(),
        chapterIndexes: (json['chapterIndexes'] as List? ?? const [])
            .whereType<num>()
            .map((value) => value.toInt())
            .toList(),
      );
}

final class DocumentClusterAttribution {
  const DocumentClusterAttribution({
    required this.documentId,
    required this.documentNodeId,
    required this.clusterId,
    required this.similarity,
    required this.citation,
  });

  final String documentId;
  final String documentNodeId;
  final String clusterId;
  final double similarity;
  final DocumentCitation citation;

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'documentNodeId': documentNodeId,
    'clusterId': clusterId,
    'similarity': similarity,
    'citation': citation.toJson(),
  };

  factory DocumentClusterAttribution.fromJson(Map<String, dynamic> json) =>
      DocumentClusterAttribution(
        documentId: json['documentId'] as String,
        documentNodeId: json['documentNodeId'] as String,
        clusterId: json['clusterId'] as String,
        similarity: (json['similarity'] as num).toDouble(),
        citation: DocumentCitation.fromJson(
          Map<String, dynamic>.from(json['citation'] as Map),
        ),
      );
}

final class DocumentOverlaySnapshot {
  DocumentOverlaySnapshot({
    Iterable<GraphNode> nodes = const [],
    Iterable<GraphEdge> edges = const [],
    Map<String, DocumentCitation> citations = const {},
    Iterable<DocumentClusterAttribution> attributions = const [],
    Iterable<String> tombstonedDocumentIds = const [],
  }) : nodes = List.unmodifiable(nodes),
       edges = List.unmodifiable(edges),
       citations = Map.unmodifiable(citations),
       attributions = List.unmodifiable(attributions),
       tombstonedDocumentIds = Set.unmodifiable(tombstonedDocumentIds);

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, DocumentCitation> citations;
  final List<DocumentClusterAttribution> attributions;
  final Set<String> tombstonedDocumentIds;

  PersonalKnowledgeGraph get graph =>
      PersonalKnowledgeGraph(nodes: nodes, edges: edges);

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'nodes': nodes.map((node) => node.toJson()).toList(),
    'edges': edges.map((edge) => edge.toJson()).toList(),
    'citations': citations.map(
      (nodeId, citation) => MapEntry(nodeId, citation.toJson()),
    ),
    'attributions': attributions
        .map((attribution) => attribution.toJson())
        .toList(),
    'tombstonedDocumentIds': tombstonedDocumentIds.toList()..sort(),
  };

  factory DocumentOverlaySnapshot.fromJson(Map<String, dynamic> json) =>
      DocumentOverlaySnapshot(
        nodes: (json['nodes'] as List? ?? const []).whereType<Map>().map(
          (row) => GraphNode.fromJson(Map<String, dynamic>.from(row)),
        ),
        edges: (json['edges'] as List? ?? const []).whereType<Map>().map(
          (row) => GraphEdge.fromJson(Map<String, dynamic>.from(row)),
        ),
        citations: (json['citations'] as Map? ?? const {}).map(
          (key, value) => MapEntry(
            key.toString(),
            DocumentCitation.fromJson(Map<String, dynamic>.from(value as Map)),
          ),
        ),
        attributions: (json['attributions'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (row) => DocumentClusterAttribution.fromJson(
                Map<String, dynamic>.from(row),
              ),
            ),
        tombstonedDocumentIds:
            (json['tombstonedDocumentIds'] as List? ?? const [])
                .whereType<String>(),
      );
}

final class DocumentGraphOverlayStore {
  DocumentGraphOverlayStore({required this.storage});

  final EncryptedJsonFileStore storage;
  final StreamController<int> _revisions = StreamController<int>.broadcast(
    sync: true,
  );
  Future<void> _tail = Future<void>.value();
  int _revision = 0;
  Map<String, dynamic>? _rollbackJson;

  Stream<int> get revisions => _revisions.stream;
  int get revision => _revision;

  Future<DocumentOverlaySnapshot> load() => _serialized(_load);

  Future<void> save(DocumentOverlaySnapshot snapshot) => _serialized(() async {
    final current = await _load();
    _rollbackJson = current.toJson();
    await storage.writeJson(snapshot.toJson());
    _notify();
  });

  Future<bool> rollback() => _serialized(() async {
    final rollback = _rollbackJson;
    if (rollback == null) return false;
    await storage.writeJson(rollback);
    _rollbackJson = null;
    _notify();
    return true;
  });

  Future<void> clear() => save(DocumentOverlaySnapshot());

  Future<DocumentOverlaySnapshot> _load() async {
    try {
      final raw = await storage.readJson();
      if (raw is! Map || raw.isEmpty) return DocumentOverlaySnapshot();
      return DocumentOverlaySnapshot.fromJson(Map<String, dynamic>.from(raw));
    } on Object {
      return DocumentOverlaySnapshot();
    }
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
    _revisions.add(_revision);
  }

  Future<void> dispose() async {
    await _tail.catchError((Object _) {});
    await _revisions.close();
  }
}

final class DocumentGraphMapper {
  const DocumentGraphMapper({
    required this.semanticIndex,
    required this.overlayStore,
    this.minimumSimilarity = .82,
    this.maxLinksPerDocument = 24,
  });

  final DocumentSemanticIndex semanticIndex;
  final DocumentGraphOverlayStore overlayStore;
  final double minimumSimilarity;
  final int maxLinksPerDocument;

  Future<DocumentOverlaySnapshot> mapDocument({
    required String documentId,
    required List<DocumentChunk> chunks,
    required PersonalKnowledgeGraph personalGraph,
    required List<SemanticCluster> clusters,
    Set<String> rejectedNodeIds = const {},
  }) async {
    final records = await semanticIndex.indexDocument(documentId, chunks);
    final chunkByIndex = {for (final chunk in chunks) chunk.index: chunk};
    final personalNodes =
        personalGraph.nodes
            .where(
              (node) =>
                  node.origin != NodeOrigin.document &&
                  node.archivedAt == null &&
                  !rejectedNodeIds.contains(node.id),
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));
    final nodeEmbeddings = {
      for (final node in personalNodes)
        node.id: semanticIndex.embeddingDriver.embed(node.label),
    };
    final clusterEmbeddings = <String, Float32List>{};
    for (final cluster
        in clusters.toList()
          ..sort((left, right) => left.id.compareTo(right.id))) {
      final members = cluster.nodeIds
          .where((nodeId) => nodeEmbeddings.containsKey(nodeId))
          .map((nodeId) => nodeEmbeddings[nodeId]!)
          .toList();
      if (members.isNotEmpty) {
        clusterEmbeddings[cluster.id] = _centroid(
          members,
          semanticIndex.embeddingDriver.dimensions,
        );
      }
    }

    final candidates = <_BridgeCandidate>[];
    final clusterCandidates = <_ClusterCandidate>[];
    for (final record in records) {
      final chunk = chunkByIndex[record.chunkIndex]!;
      final citation = DocumentCitation(
        documentId: documentId,
        chunkIndex: chunk.index,
        startChar: chunk.startChar,
        endChar: chunk.endChar,
        pageNumbers: chunk.pageNumbers,
        chapterIndexes: chunk.chapterIndexes,
      );
      for (final node in personalNodes) {
        final score = _cosine(record.embedding, nodeEmbeddings[node.id]!);
        if (score > minimumSimilarity) {
          candidates.add(
            _BridgeCandidate(record, chunk, node, score, citation),
          );
        }
      }
      for (final entry in clusterEmbeddings.entries) {
        final score = _cosine(record.embedding, entry.value);
        if (score > minimumSimilarity) {
          clusterCandidates.add(
            _ClusterCandidate(record, chunk, entry.key, score, citation),
          );
        }
      }
    }
    candidates.sort(_compareBridge);
    clusterCandidates.sort(_compareCluster);

    final selected = candidates.take(maxLinksPerDocument).toList();
    final selectedClusters = clusterCandidates
        .take(maxLinksPerDocument)
        .toList();
    final documentNodeByChunk = <int, GraphNode>{};
    GraphNode documentNode(DocumentChunk chunk, double confidence) =>
        documentNodeByChunk.putIfAbsent(
          chunk.index,
          () => GraphNode(
            id: 'docnode_${_hash('$documentId:${chunk.index}')}',
            type: NodeType.topic,
            label: _label(chunk.text),
            confidence: confidence,
            origin: NodeOrigin.document,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );

    final current = await overlayStore.load();
    final retainedNodes = current.nodes
        .where((node) => current.citations[node.id]?.documentId != documentId)
        .toList();
    final removedNodeIds = current.citations.entries
        .where((entry) => entry.value.documentId == documentId)
        .map((entry) => entry.key)
        .toSet();
    final retainedEdges = current.edges
        .where(
          (edge) =>
              !removedNodeIds.contains(edge.sourceNodeId) &&
              !removedNodeIds.contains(edge.targetNodeId),
        )
        .toList();
    final citations = Map<String, DocumentCitation>.from(current.citations)
      ..removeWhere((_, citation) => citation.documentId == documentId);
    final edges = <GraphEdge>[...retainedEdges];

    for (final candidate in selected) {
      final node = documentNode(candidate.chunk, candidate.score);
      citations[node.id] = candidate.citation;
      edges.add(
        GraphEdge(
          id: 'docedge_${_hash('${node.id}:${candidate.target.id}')}',
          sourceNodeId: node.id,
          targetNodeId: candidate.target.id,
          type: EdgeType.associatedWith,
          isDirected: false,
          weight: candidate.score,
          origin: NodeOrigin.document,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
    }
    final attributions = <DocumentClusterAttribution>[
      ...current.attributions.where(
        (attribution) => attribution.documentId != documentId,
      ),
      for (final candidate in selectedClusters)
        DocumentClusterAttribution(
          documentId: documentId,
          documentNodeId: documentNode(candidate.chunk, candidate.score).id,
          clusterId: candidate.clusterId,
          similarity: candidate.score,
          citation: candidate.citation,
        ),
    ];
    for (final node in documentNodeByChunk.values) {
      citations.putIfAbsent(
        node.id,
        () => DocumentCitation(
          documentId: documentId,
          chunkIndex: chunkByIndex.entries
              .firstWhere(
                (entry) => documentNodeByChunk[entry.key]?.id == node.id,
              )
              .key,
          startChar: records
              .firstWhere(
                (record) =>
                    documentNodeByChunk[record.chunkIndex]?.id == node.id,
              )
              .startChar,
          endChar: records
              .firstWhere(
                (record) =>
                    documentNodeByChunk[record.chunkIndex]?.id == node.id,
              )
              .endChar,
          pageNumbers: const [],
          chapterIndexes: const [],
        ),
      );
    }

    final next = DocumentOverlaySnapshot(
      nodes: [...retainedNodes, ...documentNodeByChunk.values],
      edges: edges,
      citations: citations,
      attributions: attributions,
      tombstonedDocumentIds: current.tombstonedDocumentIds.where(
        (id) => id != documentId,
      ),
    );
    await overlayStore.save(next);
    return next;
  }

  Future<void> removeDocument(String documentId) async {
    await semanticIndex.removeDocument(documentId);
    final current = await overlayStore.load();
    final removedNodeIds = current.citations.entries
        .where((entry) => entry.value.documentId == documentId)
        .map((entry) => entry.key)
        .toSet();
    await overlayStore.save(
      DocumentOverlaySnapshot(
        nodes: current.nodes.where((node) => !removedNodeIds.contains(node.id)),
        edges: current.edges.where(
          (edge) =>
              !removedNodeIds.contains(edge.sourceNodeId) &&
              !removedNodeIds.contains(edge.targetNodeId),
        ),
        citations: Map<String, DocumentCitation>.from(current.citations)
          ..removeWhere((_, citation) => citation.documentId == documentId),
        attributions: current.attributions.where(
          (attribution) => attribution.documentId != documentId,
        ),
        tombstonedDocumentIds: {...current.tombstonedDocumentIds, documentId},
      ),
    );
  }

  Future<bool> rollbackLastMapping() async {
    final vectorsRestored = await semanticIndex.rollback();
    final overlayRestored = await overlayStore.rollback();
    return vectorsRestored && overlayRestored;
  }
}

final class _BridgeCandidate {
  const _BridgeCandidate(
    this.record,
    this.chunk,
    this.target,
    this.score,
    this.citation,
  );

  final DocumentVectorRecord record;
  final DocumentChunk chunk;
  final GraphNode target;
  final double score;
  final DocumentCitation citation;
}

final class _ClusterCandidate {
  const _ClusterCandidate(
    this.record,
    this.chunk,
    this.clusterId,
    this.score,
    this.citation,
  );

  final DocumentVectorRecord record;
  final DocumentChunk chunk;
  final String clusterId;
  final double score;
  final DocumentCitation citation;
}

int _compareBridge(_BridgeCandidate left, _BridgeCandidate right) {
  final score = right.score.compareTo(left.score);
  if (score != 0) return score;
  final chunk = left.chunk.index.compareTo(right.chunk.index);
  return chunk != 0 ? chunk : left.target.id.compareTo(right.target.id);
}

int _compareCluster(_ClusterCandidate left, _ClusterCandidate right) {
  final score = right.score.compareTo(left.score);
  if (score != 0) return score;
  final chunk = left.chunk.index.compareTo(right.chunk.index);
  return chunk != 0 ? chunk : left.clusterId.compareTo(right.clusterId);
}

Float32List _centroid(Iterable<Float32List> vectors, int dimensions) {
  final values = vectors.toList();
  final centroid = Float32List(dimensions);
  for (final vector in values) {
    for (var index = 0; index < dimensions; index++) {
      centroid[index] += vector[index];
    }
  }
  var norm = 0.0;
  for (var index = 0; index < dimensions; index++) {
    centroid[index] /= values.length;
    norm += centroid[index] * centroid[index];
  }
  if (norm > 0) {
    final scale = 1 / math.sqrt(norm);
    for (var index = 0; index < dimensions; index++) {
      centroid[index] *= scale;
    }
  }
  return centroid;
}

double _cosine(Float32List left, Float32List right) {
  var dot = 0.0;
  var leftNorm = 0.0;
  var rightNorm = 0.0;
  for (var index = 0; index < left.length; index++) {
    dot += left[index] * right[index];
    leftNorm += left[index] * left[index];
    rightNorm += right[index] * right[index];
  }
  if (leftNorm == 0 || rightNorm == 0) return 0;
  return dot / math.sqrt(leftNorm * rightNorm);
}

String _label(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 72) return normalized;
  return '${normalized.substring(0, 69).trimRight()}…';
}

String _hash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
