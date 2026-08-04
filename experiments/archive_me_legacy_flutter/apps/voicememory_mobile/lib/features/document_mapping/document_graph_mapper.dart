// ignore_for_file: prefer_initializing_formals

import 'dart:typed_data';

import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/search/local_vector_search_engine.dart';
import '../document_ingestion/document_models.dart';
import 'document_concept_extractor.dart';
import 'document_graph_overlay_store.dart';
import 'document_semantic_index.dart';
import 'document_vector_store.dart';

final class DocumentClusterCentroid {
  DocumentClusterCentroid({
    required this.clusterId,
    required Float32List vector,
  }) : vector = Float32List.fromList(vector);

  final String clusterId;
  final Float32List vector;
}

final class DocumentMappingResult {
  DocumentMappingResult({
    required Iterable<GraphNode> nodes,
    required Iterable<GraphEdge> bridgeEdges,
    required Iterable<DocumentCitation> citations,
    required Iterable<DocumentClusterAttribution> attributions,
  }) : nodes = List.unmodifiable(nodes),
       bridgeEdges = List.unmodifiable(bridgeEdges),
       citations = List.unmodifiable(citations),
       attributions = List.unmodifiable(attributions);

  final List<GraphNode> nodes;
  final List<GraphEdge> bridgeEdges;
  final List<DocumentCitation> citations;
  final List<DocumentClusterAttribution> attributions;
}

/// Maps document-only nodes into an isolated overlay using strict cosine gates.
final class DocumentGraphMapper {
  DocumentGraphMapper({
    LocalEmbeddingDriver embeddingDriver = const HashedLocalEmbeddingDriver(),
    LocalDocumentConceptExtractor conceptExtractor =
        const LocalDocumentConceptExtractor(),
    this.semanticIndex,
    this.vectorStore,
    this.overlayStore,
    this.minimumSimilarity = 0.82,
    this.maximumBridgeEdgesPerDocument = 24,
    this.maximumAttributionsPerDocument = 12,
  }) : _embeddingDriver = embeddingDriver,
       _conceptExtractor = conceptExtractor {
    if (minimumSimilarity < -1 || minimumSimilarity > 1) {
      throw ArgumentError.value(minimumSimilarity, 'minimumSimilarity');
    }
  }

  final LocalEmbeddingDriver _embeddingDriver;
  final LocalDocumentConceptExtractor _conceptExtractor;
  final DocumentSemanticIndex? semanticIndex;
  final DocumentVectorStore? vectorStore;
  final DocumentGraphOverlayStore? overlayStore;
  final double minimumSimilarity;
  final int maximumBridgeEdgesPerDocument;
  final int maximumAttributionsPerDocument;

  DocumentMappingResult mapDocument({
    required String documentId,
    required Iterable<DocumentSemanticRecord> records,
    required PersonalKnowledgeGraph personalGraph,
    Iterable<DocumentClusterCentroid> clusterCentroids = const [],
    Set<String> rejectedNodeIds = const {},
  }) {
    final orderedRecords = records.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final nodes = <GraphNode>[];
    final citations = <DocumentCitation>[];
    for (final record in orderedRecords) {
      final nodeId = record.id;
      nodes.add(
        GraphNode(
          id: nodeId,
          type: record.kind == DocumentSemanticRecordKind.concept
              ? NodeType.topic
              : NodeType.text,
          label: _label(record.text),
          confidence: 1,
          origin: NodeOrigin.document,
          createdAt: record.updatedAt,
        ),
      );
      citations.add(
        DocumentCitation(
          id: '$nodeId:citation',
          documentId: documentId,
          nodeId: nodeId,
          recordId: record.id,
          startChar: record.startChar,
          endChar: record.endChar,
          excerpt: record.text,
        ),
      );
    }

    final personalCandidates = personalGraph.nodes
        .where(
          (node) =>
              !rejectedNodeIds.contains(node.id) &&
              node.archivedAt == null &&
              node.origin != NodeOrigin.document,
        )
        .map(
          (node) => (
            node: node,
            vector: _embeddingDriver.embed('${node.label} ${node.type.name}'),
          ),
        )
        .toList();
    final bridgeCandidates = <_BridgeCandidate>[];
    for (final record in orderedRecords) {
      for (final candidate in personalCandidates) {
        final score = _stableScore(
          LocalVectorSearchEngine.cosineSimilarity(
            record.vector,
            candidate.vector,
          ),
        );
        if (score > minimumSimilarity) {
          bridgeCandidates.add((
            record: record,
            target: candidate.node,
            score: score,
          ));
        }
      }
    }
    bridgeCandidates.sort(_bridgeSort);
    final bridges = <GraphEdge>[];
    final usedRecords = <String>{};
    for (final candidate in bridgeCandidates) {
      if (bridges.length >= maximumBridgeEdgesPerDocument) break;
      if (!usedRecords.add(candidate.record.id)) continue;
      bridges.add(
        GraphEdge(
          id:
              'document:$documentId:bridge:${candidate.record.id}:'
              '${candidate.target.id}',
          sourceNodeId: candidate.record.id,
          targetNodeId: candidate.target.id,
          type: EdgeType.associatedWith,
          isDirected: false,
          weight: candidate.score,
          origin: NodeOrigin.document,
          createdAt: candidate.record.updatedAt,
        ),
      );
    }

    final attributionCandidates = <_AttributionCandidate>[];
    for (final centroid in clusterCentroids) {
      if (centroid.vector.length != _embeddingDriver.dimensions) {
        throw ArgumentError('Cluster centroid dimension mismatch.');
      }
      for (final record in orderedRecords) {
        final score = _stableScore(
          LocalVectorSearchEngine.cosineSimilarity(
            record.vector,
            centroid.vector,
          ),
        );
        if (score > minimumSimilarity) {
          attributionCandidates.add((
            record: record,
            clusterId: centroid.clusterId,
            score: score,
          ));
        }
      }
    }
    attributionCandidates.sort(_attributionSort);
    final attributions = <DocumentClusterAttribution>[];
    final attributedRecords = <String>{};
    for (final candidate in attributionCandidates) {
      if (attributions.length >= maximumAttributionsPerDocument) break;
      if (!attributedRecords.add(candidate.record.id)) continue;
      attributions.add(
        DocumentClusterAttribution(
          id:
              'document:$documentId:attribution:${candidate.record.id}:'
              '${candidate.clusterId}',
          documentId: documentId,
          recordId: candidate.record.id,
          clusterId: candidate.clusterId,
          score: candidate.score,
        ),
      );
    }
    return DocumentMappingResult(
      nodes: nodes,
      bridgeEdges: bridges,
      citations: citations,
      attributions: attributions,
    );
  }

  Future<DocumentMappingResult> reindexDocument({
    required String documentId,
    required Iterable<DocumentChunk> chunks,
    required PersonalKnowledgeGraph personalGraph,
    Iterable<DocumentConcept>? concepts,
    Iterable<DocumentClusterCentroid> clusterCentroids = const [],
    Set<String> rejectedNodeIds = const {},
  }) async {
    final index = _requiredIndex();
    final typedChunks = chunks.toList(growable: false);
    final extractedConcepts =
        concepts ?? _conceptExtractor.extract(typedChunks);
    final documentRecords = await index.indexDocument(
      documentId: documentId,
      chunks: typedChunks,
      concepts: extractedConcepts,
    );
    final snapshot = await index.load();
    vectorStore?.rebuild(snapshot);
    final result = mapDocument(
      documentId: documentId,
      records: documentRecords,
      personalGraph: personalGraph,
      clusterCentroids: clusterCentroids,
      rejectedNodeIds: rejectedNodeIds,
    );
    await _requiredOverlay().replaceDocument(
      documentId: documentId,
      nodes: result.nodes,
      edges: result.bridgeEdges,
      citations: result.citations,
      attributions: result.attributions,
    );
    return result;
  }

  Future<void> removeDocument(String documentId) async {
    final index = _requiredIndex();
    await index.removeDocument(documentId);
    final snapshot = await index.load();
    vectorStore?.removeDocument(documentId, snapshot);
    await _requiredOverlay().removeDocument(documentId);
  }

  Future<void> rollbackDocument(String documentId) async {
    final index = _requiredIndex();
    await index.rollbackDocument(documentId);
    final snapshot = await index.load();
    vectorStore?.rollbackDocument(documentId, snapshot);
    await _requiredOverlay().rollbackDocument(documentId);
  }

  DocumentSemanticIndex _requiredIndex() =>
      semanticIndex ??
      (throw StateError('DocumentSemanticIndex is required for mutation.'));

  DocumentGraphOverlayStore _requiredOverlay() =>
      overlayStore ??
      (throw StateError('DocumentGraphOverlayStore is required for mutation.'));

  static String _label(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.length <= 120 ? normalized : normalized.substring(0, 120);
  }

  // sqlite-vec and Float32List can differ by a few ULPs at the policy boundary.
  static double _stableScore(double value) =>
      (value * 1000000).roundToDouble() / 1000000;

  static int _bridgeSort(_BridgeCandidate left, _BridgeCandidate right) {
    final byScore = right.score.compareTo(left.score);
    if (byScore != 0) return byScore;
    final byTarget = left.target.id.compareTo(right.target.id);
    return byTarget != 0 ? byTarget : left.record.id.compareTo(right.record.id);
  }

  static int _attributionSort(
    _AttributionCandidate left,
    _AttributionCandidate right,
  ) {
    final byScore = right.score.compareTo(left.score);
    if (byScore != 0) return byScore;
    final byCluster = left.clusterId.compareTo(right.clusterId);
    return byCluster != 0
        ? byCluster
        : left.record.id.compareTo(right.record.id);
  }
}

typedef _BridgeCandidate = ({
  DocumentSemanticRecord record,
  GraphNode target,
  double score,
});

typedef _AttributionCandidate = ({
  DocumentSemanticRecord record,
  String clusterId,
  double score,
});
