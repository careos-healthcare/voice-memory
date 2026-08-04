import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/voice_conversation/graph_retrieval_tool.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late LocalSemanticStore semanticStore;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('graph_retrieval_tool_');
    semanticStore = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('maps local vector records and graph traversal to tool JSON', () async {
    const quote = 'Work deadlines left me feeling burned out.';
    final observedAt = DateTime.utc(2026, 7, 20);
    final work = GraphNode(
      id: 'work',
      type: NodeType.project,
      label: 'Work',
      confidence: .9,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry-1',
          observedAt: observedAt,
          confidence: .95,
          excerpt: quote,
          startUtf16: 0,
          endUtf16: quote.length,
        ),
      ],
    );
    final burnout = GraphNode(
      id: 'burnout',
      type: NodeType.emotion,
      label: 'Burnout',
      confidence: .85,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry-1',
          observedAt: observedAt,
          confidence: .9,
          excerpt: quote,
          startUtf16: 0,
          endUtf16: quote.length,
        ),
      ],
    );
    final edgeQuote = 'Work connected with burnout.';
    final graph = PersonalKnowledgeGraph(
      nodes: [work, burnout],
      edges: [
        GraphEdge(
          sourceNodeId: work.id,
          targetNodeId: burnout.id,
          type: EdgeType.associatedWith,
          isDirected: false,
          weight: .8,
          evidence: [
            GraphEdgeEvidence(
              entryId: 'entry-1',
              observedAt: observedAt,
              confidence: .9,
              excerpt: edgeQuote,
              startUtf16: 0,
              endUtf16: edgeQuote.length,
            ),
          ],
        ),
      ],
    );
    final entry = JournalEntry(
      id: 'entry-1',
      createdAt: observedAt,
      transcript: quote,
      durationSeconds: 12,
      reflection: const Reflection(
        mood: 'tired',
        emotionalIntensity: 7,
        recurringThemes: ['work'],
        exactLanguagePattern: quote,
        concreteObservation: 'Work pressure was present.',
        repeatedSignal: '',
      ),
    );
    await semanticStore.upsertFromGraph(entry, graph);
    final tool = GraphRetrievalTool(
      semanticStore: semanticStore,
      loadGraph: () async => graph,
      clock: () => DateTime.utc(2026, 7, 27),
    );

    final encoded = await tool.executeJson({
      'topic': 'work burnout',
      'timeframe': 'last 30 days',
    });
    final result = jsonDecode(encoded) as Map<String, dynamic>;
    final nodes = result['nodes'] as List;

    expect(result['resultCount'], 2);
    expect(nodes, hasLength(2));
    expect(encoded, contains(quote));
    expect(encoded, contains('associatedWith'));
    expect(result['privacy'], contains('locally'));
  });

  test('excludes evidence outside requested timeframe', () async {
    const quote = 'An old project memory.';
    final node = GraphNode(
      id: 'old',
      type: NodeType.project,
      label: 'Old project',
      confidence: .8,
      evidence: [
        GraphNodeEvidence(
          entryId: 'old-entry',
          observedAt: DateTime.utc(2024),
          confidence: .8,
          excerpt: quote,
          startUtf16: 0,
          endUtf16: quote.length,
        ),
      ],
    );
    final tool = GraphRetrievalTool(
      semanticStore: semanticStore,
      loadGraph: () async => PersonalKnowledgeGraph(nodes: [node]),
      clock: () => DateTime.utc(2026, 7, 27),
    );

    final result = await tool.query(
      topic: 'old project',
      timeframe: 'last 30 days',
    );

    expect(result['nodes'], isEmpty);
  });
}
