import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_graph_mapper.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_models.dart';
import 'package:voicememory_mobile/features/document_ingestion/document_semantic_index.dart';
import 'package:voicememory_mobile/features/semantic_clusters/semantic_cluster.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  group('DocumentGraphMapper', () {
    late Directory directory;
    late DocumentSemanticIndex index;
    late DocumentGraphOverlayStore overlay;
    late DocumentGraphMapper mapper;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('document_mapper_');
      final keyStore = InMemoryPrivateDataEncryptionKeyStore();
      await keyStore.ensureKey();
      index = DocumentSemanticIndex(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/vectors.enc'),
          keyStore: keyStore,
        ),
        vectorStore: await SqliteVecVectorStore.open(
          databasePath: '${directory.path}/vectors.sqlite3',
          dimensions: 2,
        ),
        embeddingDriver: const _FixtureEmbeddingDriver(),
        clock: () => DateTime.utc(2026, 7, 21),
      );
      overlay = DocumentGraphOverlayStore(
        storage: EncryptedJsonFileStore(
          file: File('${directory.path}/overlay.enc'),
          keyStore: keyStore,
        ),
      );
      mapper = DocumentGraphMapper(semanticIndex: index, overlayStore: overlay);
    });

    tearDown(() async {
      await overlay.dispose();
      await index.dispose();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test(
      'creates deterministic overlay bridges above threshold only',
      () async {
        final exact = GraphNode(
          id: 'personal_exact',
          type: NodeType.topic,
          label: 'exact',
          confidence: 1,
          origin: NodeOrigin.manual,
        );
        final below = GraphNode(
          id: 'personal_below',
          type: NodeType.topic,
          label: 'below',
          confidence: 1,
          origin: NodeOrigin.manual,
        );
        final personal = PersonalKnowledgeGraph(nodes: [below, exact]);
        final cluster = SemanticCluster(
          id: 'cluster_exact',
          title: 'Exact',
          category: SemanticClusterCategory.theme,
          nodeIds: [exact.id],
          activityVelocity: .5,
          confidenceScore: .9,
        );

        final result = await mapper.mapDocument(
          documentId: 'doc_fixture',
          chunks: [_chunk()],
          personalGraph: personal,
          clusters: [cluster],
        );

        expect(result.nodes, hasLength(1));
        expect(result.nodes.single.origin, NodeOrigin.document);
        expect(result.edges, hasLength(1));
        expect(result.edges.single.targetNodeId, exact.id);
        expect(result.edges.single.origin, NodeOrigin.document);
        expect(result.attributions.single.clusterId, cluster.id);
        expect(result.citations.values.single.startChar, 0);
        expect(personal.nodes, same(personal.nodes));
      },
    );

    test('sqlite-vec cache sorts precomputed local embeddings', () async {
      await index.indexDocument('doc_alpha', [_chunk()]);
      await index.indexDocument('doc_other', [
        DocumentChunk(
          index: 0,
          text: 'other',
          startChar: 0,
          endChar: 5,
          tokenCount: 1,
          pageNumbers: const [],
          chapterIndexes: const [],
        ),
      ]);

      final hits = await index.searchText('alpha', limit: 2);
      expect(hits.first.record.documentId, 'doc_alpha');
      expect(hits.first.similarity, greaterThan(hits.last.similarity));
    });

    test('honors rejected nodes and isolates personal evidence', () async {
      final exact = GraphNode(
        id: 'rejected_exact',
        type: NodeType.topic,
        label: 'exact',
        confidence: 1,
        origin: NodeOrigin.manual,
      );
      final personal = PersonalKnowledgeGraph(nodes: [exact]);

      final result = await mapper.mapDocument(
        documentId: 'doc_fixture',
        chunks: [_chunk()],
        personalGraph: personal,
        clusters: const [],
        rejectedNodeIds: {exact.id},
      );

      expect(result.edges, isEmpty);
      expect(result.nodes, isEmpty);
      expect(personal.nodes.single.origin, NodeOrigin.manual);
      expect(personal.nodes.single.evidence, isEmpty);
    });

    test('deletion and rollback never mutate personal nodes', () async {
      final exact = GraphNode(
        id: 'personal_exact',
        type: NodeType.topic,
        label: 'exact',
        confidence: 1,
        origin: NodeOrigin.manual,
      );
      final personal = PersonalKnowledgeGraph(nodes: [exact]);
      await mapper.mapDocument(
        documentId: 'doc_fixture',
        chunks: [_chunk()],
        personalGraph: personal,
        clusters: const [],
      );

      await mapper.removeDocument('doc_fixture');
      expect((await overlay.load()).nodes, isEmpty);
      expect(await index.records(), isEmpty);

      expect(await mapper.rollbackLastMapping(), isTrue);
      expect((await overlay.load()).nodes, isNotEmpty);
      expect(await index.records(), isNotEmpty);
      expect(personal.nodes.single.id, exact.id);
    });
  });
}

DocumentChunk _chunk() => DocumentChunk(
  index: 0,
  text: 'alpha',
  startChar: 0,
  endChar: 5,
  tokenCount: 1,
  pageNumbers: const [1],
  chapterIndexes: const [],
);

final class _FixtureEmbeddingDriver implements LocalEmbeddingDriver {
  const _FixtureEmbeddingDriver();

  @override
  int get dimensions => 2;

  @override
  Float32List embed(String text) => switch (text) {
    'alpha' || 'exact' => Float32List.fromList(const [1, 0]),
    'below' => Float32List.fromList([.81, math.sqrt(1 - (.81 * .81))]),
    _ => Float32List.fromList(const [0, 1]),
  };
}
