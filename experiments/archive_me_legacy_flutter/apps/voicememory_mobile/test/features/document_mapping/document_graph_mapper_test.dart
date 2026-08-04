import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_models.dart';
import 'package:voicememory_mobile/features/document_mapping/document_graph_mapper.dart';
import 'package:voicememory_mobile/features/document_mapping/document_graph_overlay_store.dart';
import 'package:voicememory_mobile/features/document_mapping/document_semantic_index.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  const driver = _TestEmbeddingDriver();
  final epoch = DateTime.utc(2026, 7, 28);

  DocumentSemanticRecord record(
    String id,
    List<double> vector, {
    String text = 'alpha',
  }) => DocumentSemanticRecord(
    id: 'document:doc:$id',
    documentId: 'doc',
    kind: DocumentSemanticRecordKind.chunk,
    text: text,
    sourceIndex: 0,
    startChar: 0,
    endChar: text.length,
    vector: Float32List.fromList(vector),
    updatedAt: epoch,
  );

  test('uses strict threshold and deterministic score/id sorting', () {
    final boundary = record('boundary', [.82, math.sqrt(1 - (.82 * .82))]);
    final strong = record('strong', [1, 0]);
    final graph = PersonalKnowledgeGraph(
      nodes: [
        GraphNode(
          id: 'personal-b',
          type: NodeType.topic,
          label: 'alpha b',
          confidence: 1,
        ),
        GraphNode(
          id: 'personal-a',
          type: NodeType.topic,
          label: 'alpha a',
          confidence: 1,
        ),
      ],
    );
    final result =
        DocumentGraphMapper(
          embeddingDriver: driver,
          maximumBridgeEdgesPerDocument: 3,
        ).mapDocument(
          documentId: 'doc',
          records: [boundary, strong],
          personalGraph: graph,
        );

    expect(result.bridgeEdges, hasLength(1));
    expect(result.bridgeEdges.single.sourceNodeId, strong.id);
    expect(result.bridgeEdges.single.targetNodeId, 'personal-a');
    expect(result.bridgeEdges.single.weight, greaterThan(.82));
  });

  test('attributes records to best centroid with deterministic tie break', () {
    final result = DocumentGraphMapper(embeddingDriver: driver).mapDocument(
      documentId: 'doc',
      records: [
        record('one', [1, 0]),
      ],
      personalGraph: PersonalKnowledgeGraph(),
      clusterCentroids: [
        DocumentClusterCentroid(
          clusterId: 'cluster-z',
          vector: Float32List.fromList([1, 0]),
        ),
        DocumentClusterCentroid(
          clusterId: 'cluster-a',
          vector: Float32List.fromList([1, 0]),
        ),
      ],
    );

    expect(result.attributions, hasLength(1));
    expect(result.attributions.single.clusterId, 'cluster-a');
  });

  test('excludes rejected nodes and keeps bridges isolated in overlay', () {
    final personal = GraphNode(
      id: 'personal-a',
      type: NodeType.topic,
      label: 'alpha',
      confidence: 1,
    );
    final graph = PersonalKnowledgeGraph(nodes: [personal]);
    final mapper = DocumentGraphMapper(embeddingDriver: driver);

    final rejected = mapper.mapDocument(
      documentId: 'doc',
      records: [
        record('one', [1, 0]),
      ],
      personalGraph: graph,
      rejectedNodeIds: {'personal-a'},
    );
    expect(rejected.bridgeEdges, isEmpty);

    final mapped = mapper.mapDocument(
      documentId: 'doc',
      records: [
        record('one', [1, 0]),
      ],
      personalGraph: graph,
    );
    expect(graph.nodes, same(graph.nodes));
    expect(graph.nodes.single, same(personal));
    expect(
      mapped.nodes.every((node) => node.origin == NodeOrigin.document),
      true,
    );
    expect(
      mapped.bridgeEdges.every((edge) => edge.origin == NodeOrigin.document),
      true,
    );
    expect(mapped.nodes.map((node) => node.id), isNot(contains('personal-a')));
  });

  group('encrypted lifecycle', () {
    late Directory directory;
    late DocumentSemanticIndex index;
    late DocumentGraphOverlayStore overlay;
    late DocumentGraphMapper mapper;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('document_mapping_');
      final keyStore = InMemoryPrivateDataEncryptionKeyStore(
        seedKey: List<int>.filled(32, 9),
      );
      index = DocumentSemanticIndex(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/index.enc'),
          keyStore: keyStore,
        ),
        embeddingDriver: driver,
        clock: () => epoch,
      );
      overlay = DocumentGraphOverlayStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/overlay.enc'),
          keyStore: keyStore,
        ),
        clock: () => epoch,
      );
      mapper = DocumentGraphMapper(
        embeddingDriver: driver,
        semanticIndex: index,
        overlayStore: overlay,
      );
    });

    tearDown(() async {
      await overlay.dispose();
      await directory.delete(recursive: true);
    });

    test('remove deletes vectors, overlay records, and attributions', () async {
      await _reindex(mapper);
      expect((await index.load()).forDocument('doc'), isNotEmpty);
      expect((await overlay.load()).attributions, isNotEmpty);

      await mapper.removeDocument('doc');

      expect((await index.load()).forDocument('doc'), isEmpty);
      final snapshot = await overlay.load();
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.edges, isEmpty);
      expect(snapshot.citations, isEmpty);
      expect(snapshot.attributions, isEmpty);
      expect(snapshot.tombstones.single.reason, 'removed');
    });

    test('rollback deletes document state without personal mutation', () async {
      final personal = GraphNode(
        id: 'personal-a',
        type: NodeType.topic,
        label: 'alpha',
        confidence: 1,
      );
      final graph = PersonalKnowledgeGraph(nodes: [personal]);
      await _reindex(mapper, graph: graph);

      await mapper.rollbackDocument('doc');

      expect(graph.nodes.single, same(personal));
      expect((await index.load()).forDocument('doc'), isEmpty);
      final snapshot = await overlay.load();
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.edges, isEmpty);
      expect(snapshot.attributions, isEmpty);
      expect(snapshot.tombstones.single.reason, 'rollback');
      expect(snapshot.revision, 2);
    });
  });
}

Future<void> _reindex(
  DocumentGraphMapper mapper, {
  PersonalKnowledgeGraph? graph,
}) async {
  await mapper.reindexDocument(
    documentId: 'doc',
    chunks: [
      DocumentChunk(
        index: 0,
        text: 'alpha',
        startChar: 0,
        endChar: 5,
        tokenCount: 1,
        pageNumbers: const [1],
        chapterIndexes: const [0],
      ),
    ],
    concepts: const [],
    personalGraph:
        graph ??
        PersonalKnowledgeGraph(
          nodes: [
            GraphNode(
              id: 'personal-a',
              type: NodeType.topic,
              label: 'alpha',
              confidence: 1,
            ),
          ],
        ),
    clusterCentroids: [
      DocumentClusterCentroid(
        clusterId: 'cluster-a',
        vector: Float32List.fromList([1, 0]),
      ),
    ],
  );
}

final class _TestEmbeddingDriver implements LocalEmbeddingDriver {
  const _TestEmbeddingDriver();

  @override
  int get dimensions => 2;

  @override
  Float32List embed(String text) {
    if (text.startsWith('alpha')) return Float32List.fromList([1, 0]);
    return Float32List.fromList([0, 1]);
  }
}
