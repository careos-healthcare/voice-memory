import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/core/search/local_vector_search_engine.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_models.dart';
import 'package:voicememory_mobile/features/autonomous_muse/autonomous_muse_store.dart';
import 'package:voicememory_mobile/features/autonomous_muse/semantic_bridge_builder.dart';
import 'package:voicememory_mobile/features/data_ingestion/legacy_ingestion_store.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/ai/sqlite_vec_vector_store.dart';
import 'package:voicememory_mobile/services/local_storage/encrypted_sqlite_text_codec.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test('requires cosine similarity to be strictly above 85 percent', () {
    expect(SemanticBridgeBuilder.isAboveSimilarityThreshold(.849999), isFalse);
    expect(SemanticBridgeBuilder.isAboveSimilarityThreshold(.85), isFalse);
    expect(SemanticBridgeBuilder.isAboveSimilarityThreshold(.850001), isTrue);
  });

  test('accept materializes an edge while reject does not', () async {
    final root = await Directory.systemTemp.createTemp('semantic-bridge-');
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${root.path}/$name.enc'),
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
    final graphStore = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final museStore = AutonomousMuseStore.open(
      databasePath: '${root.path}/muse.sqlite3',
      codec: EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.filled(32, 7)),
      ),
    );
    final vectorStore = await SqliteVecVectorStore.open(
      databasePath: '${root.path}/legacy-vectors.sqlite3',
      dimensions: const HashedLocalEmbeddingDriver().dimensions,
    );
    final legacyStore = await LegacyIngestionStore.open(
      databasePath: '${root.path}/legacy.sqlite3',
      codec: EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.filled(32, 9)),
      ),
      vectorStore: vectorStore,
    );
    final semanticStore = LocalSemanticStore(storage: encrypted('semantic'));
    addTearDown(() async {
      legacyStore.close();
      museStore.close();
      await semanticStore.dispose();
      await graphStore.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    });
    await graphStore.save(
      PersonalKnowledgeGraph(
        nodes: [
          _node('source', 'Zero knowledge'),
          _node('target', 'Private proofs'),
          _node('rejected-target', 'Unrelated'),
        ],
      ),
    );
    final builder = SemanticBridgeBuilder(
      legacyStore: legacyStore,
      museStore: museStore,
      graphStore: graphStore,
      semanticStore: semanticStore,
      embeddingDriver: const HashedLocalEmbeddingDriver(),
      entityAnalyzer: const _Analyzer(),
      rationaleGenerator: const _Rationale(),
      clock: () => DateTime.utc(2026, 7, 29),
    );
    museStore
      ..upsertLegacySuggestion(_suggestion('accepted', 'target'))
      ..upsertLegacySuggestion(_suggestion('rejected', 'rejected-target'));

    await builder.accept('accepted');
    builder.reject('rejected');

    final graph = await graphStore.load();
    expect(graph.edges.map((edge) => edge.id), contains('accepted'));
    expect(graph.edges.map((edge) => edge.id), isNot(contains('rejected')));
    expect(
      museStore.legacySuggestion('accepted')?.status,
      LegacyBridgeSuggestionStatus.accepted,
    );
    expect(
      museStore.legacySuggestion('rejected')?.status,
      LegacyBridgeSuggestionStatus.rejected,
    );
  });
}

GraphNode _node(String id, String label) => GraphNode(
  id: id,
  type: NodeType.text,
  label: label,
  confidence: 1,
  origin: NodeOrigin.document,
  createdAt: DateTime.utc(2026),
);

LegacyBridgeSuggestion _suggestion(String id, String targetId) =>
    LegacyBridgeSuggestion(
      id: id,
      sourceNodeId: 'source',
      targetNodeId: targetId,
      sourceLabel: 'Zero knowledge',
      targetLabel: targetId,
      entities: const ['zero-knowledge proofs'],
      confidenceScore: .91,
      rationale: 'Both notes discuss zero-knowledge proofs.',
      sourceExcerpt: 'Zero knowledge',
      createdAt: DateTime.utc(2026, 7, 29),
    );

final class _Analyzer implements LegacyEntityAnalyzer {
  const _Analyzer();

  @override
  Future<List<String>> extract(String text) async => const [];
}

final class _Rationale implements LegacyBridgeRationaleGenerator {
  const _Rationale();

  @override
  Future<LegacyBridgeRationale> generate({
    required LegacySweepNote source,
    required GraphNode target,
    required List<String> entities,
  }) async => const LegacyBridgeRationale(text: 'Related', confidence: .9);
}
