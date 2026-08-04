import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('strict cosine threshold creates only approved bridge', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp('legacy-bridge-');
    EncryptedJsonFileStore encrypted(String name) => EncryptedJsonFileStore(
      file: File('${root.path}/$name.enc'),
      keyStore: InMemoryPrivateDataEncryptionKeyStore(),
    );
    final graphStore = PersonalKnowledgeGraphStore(storage: encrypted('graph'));
    final museStore = AutonomousMuseStore.open(
      databasePath: '${root.path}/muse.sqlite3',
      codec: EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.filled(32, 11)),
      ),
    );
    final vectorStore = await SqliteVecVectorStore.open(
      databasePath: '${root.path}/legacy-vectors.sqlite3',
      dimensions: 4,
    );
    expect(
      vectorStore.isAccelerated,
      isTrue,
      reason: vectorStore.unavailableReason,
    );
    final legacyStore = await LegacyIngestionStore.open(
      databasePath: '${root.path}/legacy.sqlite3',
      codec: EncryptedSqliteTextCodec(
        () => Uint8List.fromList(List<int>.filled(32, 12)),
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
          _node('source', 'Zero knowledge research'),
          _node('definitive', 'Private proof systems'),
          _node('actionable', 'Verifiable computation'),
          _node('fringe', 'Adjacent cryptography'),
        ],
      ),
    );
    vectorStore.upsertAll([
      _record('definitive', .99, secondComponent: math.sqrt(1 - (.99 * .99))),
      _record('actionable', .90, secondComponent: math.sqrt(1 - (.90 * .90))),
      _record('fringe', .80, secondComponent: math.sqrt(1 - (.80 * .80))),
    ]);
    final builder = SemanticBridgeBuilder(
      legacyStore: legacyStore,
      museStore: museStore,
      graphStore: graphStore,
      semanticStore: semanticStore,
      embeddingDriver: const _EmbeddingDriver(),
      entityAnalyzer: const _EntityAnalyzer(),
      rationaleGenerator: const _RationaleGenerator(),
      clock: () => DateTime.utc(2026, 7, 29),
    );

    final suggestions = await builder.build(
      LegacySweepNote(
        id: 'source',
        title: 'Zero knowledge research',
        markdown: 'Alice is building a zero-knowledge proof project.',
        tags: const {'cryptography'},
      ),
    );

    expect(suggestions, hasLength(3));
    final automatic = museStore.legacySuggestions().singleWhere(
      (item) => item.targetNodeId == 'definitive',
    );
    expect(automatic.status, LegacyBridgeSuggestionStatus.autoLinked);
    expect(automatic.tags, contains('muse_auto'));
    final actionable = suggestions.singleWhere(
      (item) => item.targetNodeId == 'actionable',
    );
    expect(actionable.entities, contains('Alice'));
    expect(actionable.rationale, contains('zero-knowledge'));
    await builder.accept(actionable.id);
    final graph = await graphStore.load();
    expect(
      graph.edges.where(
        (edge) =>
            edge.sourceNodeId == 'source' &&
            {'definitive', 'actionable'}.contains(edge.targetNodeId),
      ),
      hasLength(2),
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

SqliteVecRecord _record(
  String nodeId,
  double firstComponent, {
  required double secondComponent,
}) => SqliteVecRecord(
  entryId: '$nodeId:chunk:0',
  embedding: Float32List.fromList([firstComponent, secondComponent, 0, 0]),
  clusterType: 'legacy_markdown',
  updatedAt: DateTime.utc(2026, 7, 29),
  confidence: 1,
  nodeIds: [nodeId],
  tags: const {'legacy-markdown'},
);

final class _EmbeddingDriver implements LocalEmbeddingDriver {
  const _EmbeddingDriver();

  @override
  int get dimensions => 4;

  @override
  Float32List embed(String text) => Float32List.fromList([1, 0, 0, 0]);
}

final class _EntityAnalyzer implements LegacyEntityAnalyzer {
  const _EntityAnalyzer();

  @override
  Future<List<String>> extract(String text) async => const [
    'Alice',
    'zero-knowledge proofs',
  ];
}

final class _RationaleGenerator implements LegacyBridgeRationaleGenerator {
  const _RationaleGenerator();

  @override
  Future<LegacyBridgeRationale> generate({
    required LegacySweepNote source,
    required GraphNode target,
    required List<String> entities,
  }) async => const LegacyBridgeRationale(
    text: 'Both notes discuss zero-knowledge proofs.',
    confidence: .9,
  );
}
