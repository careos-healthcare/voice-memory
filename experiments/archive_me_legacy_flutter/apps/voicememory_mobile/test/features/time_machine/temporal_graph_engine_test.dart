import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/archive_intelligence/hypothesis_tracking_engine.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/time_machine/temporal_graph_engine.dart';
import 'package:voicememory_mobile/features/time_machine/temporal_graph_history_store.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late LocalSemanticStore semantic;
  late TemporalGraphHistoryStore history;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('canvas_time_machine_');
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    semantic = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: keyStore,
      ),
    );
    history = TemporalGraphHistoryStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/history.enc'),
        keyStore: keyStore,
      ),
      clock: () => DateTime.utc(2026, 3),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('strips future entities and citations at target time', () async {
    final graph = PersonalKnowledgeGraph(
      nodes: [
        _node('past', DateTime.utc(2025), .6),
        _node('future', DateTime.utc(2027), .9),
      ],
    );
    final projected = await TemporalGraphEngine(
      semanticStore: semantic,
      historyStore: history,
    ).reconstruct(currentGraph: graph, targetTime: DateTime.utc(2026));

    expect(projected.nodes.map((node) => node.id), ['past']);
    expect(projected.nodes.single.evidence, hasLength(1));
  });

  test(
    'rolls theory confidence back to the last historical snapshot',
    () async {
      final tracker = HypothesisTrackingEngine(semantic);
      final first = await tracker.track(
        theoryId: 'theory-work',
        statement: 'Work affects rest.',
        confidenceScore: 28,
        triggeringEvidence: _citation,
        deltaReasoning: 'Early signal.',
        date: DateTime.utc(2025),
      );
      await tracker.track(
        theoryId: first.theoryId,
        statement: first.statement,
        confidenceScore: 92,
        triggeringEvidence: _citation,
        deltaReasoning: 'Repeated signal.',
        date: DateTime.utc(2026),
      );
      final graph = PersonalKnowledgeGraph(
        nodes: [
          GraphNode(
            id: 'theory-node',
            type: NodeType.belief,
            label: 'Work affects rest',
            confidence: .92,
            theoryId: first.theoryId,
            evidence: [
              _nodeEvidence(DateTime.utc(2025), .28),
              _nodeEvidence(DateTime.utc(2026), .92),
            ],
          ),
          _node('context-node', DateTime.utc(2025), .8),
        ],
        edges: [
          GraphEdge(
            id: 'theory-edge',
            sourceNodeId: 'theory-node',
            targetNodeId: 'context-node',
            type: EdgeType.associatedWith,
            isDirected: false,
            weight: .92,
            theoryId: first.theoryId,
            evidence: [
              _edgeEvidence(DateTime.utc(2025), .28),
              _edgeEvidence(DateTime.utc(2026), .92),
            ],
          ),
        ],
      );

      final projected = await TemporalGraphEngine(
        semanticStore: semantic,
      ).reconstruct(currentGraph: graph, targetTime: DateTime.utc(2025, 6));

      expect(
        projected.nodes
            .singleWhere((node) => node.id == 'theory-node')
            .confidence,
        .28,
      );
      expect(projected.edges.single.weight, .28);
      expect(projected.edges.single.evidence, hasLength(1));
    },
  );

  test('excludes entities already archived at the target date', () async {
    final graph = PersonalKnowledgeGraph(
      nodes: [
        GraphNode(
          id: 'archived',
          type: NodeType.memory,
          label: 'Archived memory',
          confidence: .8,
          createdAt: DateTime.utc(2024),
          archivedAt: DateTime.utc(2025),
          evidence: [_nodeEvidence(DateTime.utc(2024), .8)],
        ),
      ],
    );
    final projected = await TemporalGraphEngine(
      semanticStore: semantic,
    ).reconstruct(currentGraph: graph, targetTime: DateTime.utc(2025, 2));

    expect(projected.nodes, isEmpty);
  });

  test('encrypted history never writes graph labels in plaintext', () async {
    final graph = PersonalKnowledgeGraph(
      nodes: [_node('private-label', DateTime.utc(2025), .8)],
    );
    await history.append(graph);

    final bytes = await File('${root.path}/history.enc').readAsString();
    expect(bytes, isNot(contains('private-label')));
    final snapshot = await history.snapshotAt(DateTime.utc(2026, 4));
    expect(snapshot?.nodes.single.id, 'private-label');
  });
}

GraphNode _node(String id, DateTime date, double confidence) => GraphNode(
  id: id,
  type: NodeType.memory,
  label: id,
  confidence: confidence,
  evidence: [_nodeEvidence(date, confidence)],
);

GraphNodeEvidence _nodeEvidence(DateTime date, double confidence) =>
    GraphNodeEvidence(
      entryId: 'entry-${date.year}',
      observedAt: date,
      confidence: confidence,
      excerpt: 'Work affects rest',
      startUtf16: 0,
      endUtf16: 17,
    );

GraphEdgeEvidence _edgeEvidence(DateTime date, double confidence) =>
    GraphEdgeEvidence(
      entryId: 'entry-${date.year}',
      observedAt: date,
      confidence: confidence,
      excerpt: 'Work affects rest',
      startUtf16: 0,
      endUtf16: 17,
    );

const _citation = VerifiableCitation(
  sourceEntryId: 'entry-2025',
  exactQuote: 'Work affects rest',
  confidenceScore: .8,
  startUtf16: 0,
  endUtf16: 17,
);
