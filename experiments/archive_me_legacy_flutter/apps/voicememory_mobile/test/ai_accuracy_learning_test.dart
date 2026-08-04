import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph_store.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_accuracy_feedback.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/ai_engines/feedback/graph_adaptation_engine.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/shared/ui/ai_accuracy_bar.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  test(
    'accuracy feedback serializes canonically and reads legacy deferrals',
    () {
      final feedback = AiAccuracyFeedback(
        conclusionId: 'insight-json',
        confidencePercentage: 88,
        feedbackState: AiFeedbackState.incorrect,
        feedbackTimestamp: DateTime.utc(2026, 7, 27),
        correctionNote: 'This was a one-off event.',
        engine: 'weekly',
      );
      final json = feedback.toJson();
      expect(json['feedbackState'], 'incorrect');
      expect(json['correctionNote'], 'This was a one-off event.');
      expect(
        AiAccuracyFeedback.fromJson(json)?.feedbackState,
        AiFeedbackState.incorrect,
      );
      expect(
        AiAccuracyFeedback.fromJson({
          ...json,
          'feedbackState': null,
          'userFeedbackState': 'deferred',
        })?.feedbackState,
        AiFeedbackState.later,
      );
    },
  );

  testWidgets('accuracy bar morphs from pending to learning to updated', (
    tester,
  ) async {
    final initial = AiAccuracyFeedback(
      conclusionId: 'insight-1',
      confidencePercentage: 92,
    );
    final completion = Completer<AiAccuracyFeedback>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAccuracyBar(
            initialFeedback: initial,
            onSubmit: (state, note) => completion.future,
          ),
        ),
      ),
    );

    expect(find.text('92% Confidence'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_accuracy_correct')));
    await tester.pump();
    expect(find.text('Learning...'), findsOneWidget);
    completion.complete(
      initial.copyWith(
        feedbackState: AiFeedbackState.correct,
        feedbackTimestamp: DateTime.utc(2026, 7, 27),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Feedback integrated. Graph updated.'), findsOneWidget);
  });

  testWidgets('incorrect feedback uses optional correction bottom sheet', (
    tester,
  ) async {
    String? submittedNote;
    final initial = AiAccuracyFeedback(
      conclusionId: 'insight-2',
      confidencePercentage: 81,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAccuracyBar(
            initialFeedback: initial,
            onSubmit: (state, note) async {
              submittedNote = note;
              return initial.copyWith(
                feedbackState: state,
                feedbackTimestamp: DateTime.utc(2026, 7, 27),
                correctionNote: note,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ai_accuracy_incorrect')));
    await tester.pumpAndSettle();
    expect(find.text('What did we get wrong?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('ai_accuracy_correction_note')),
      'The project was already underway.',
    );
    await tester.tap(find.byKey(const Key('ai_accuracy_correction_submit')));
    await tester.pumpAndSettle();
    expect(submittedNote, 'The project was already underway.');
  });

  testWidgets('later hides the bar for seven days without learning', (
    tester,
  ) async {
    AiFeedbackState? submittedState;
    final initial = AiAccuracyFeedback(
      conclusionId: 'insight-3',
      confidencePercentage: 74,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAccuracyBar(
            initialFeedback: initial,
            onSubmit: (state, note) async {
              submittedState = state;
              return initial.copyWith(
                feedbackState: state,
                feedbackTimestamp: DateTime.now().toUtc(),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ai_accuracy_later')));
    await tester.pump();
    expect(submittedState, AiFeedbackState.later);
    expect(find.byKey(const Key('ai_accuracy_deferred')), findsOneWidget);
    expect(find.text('Learning...'), findsNothing);
  });

  test('correct feedback boosts graph trust and records anchors', () async {
    final harness = await _LearningHarness.create();
    addTearDown(harness.dispose);
    await harness.graphStore.save(_graph());
    final result =
        await GraphAdaptationEngine(
          graphStore: harness.graphStore,
          semanticStore: harness.semanticStore,
        ).apply(
          feedback: AiAccuracyFeedback(
            conclusionId: 'insight-correct',
            confidencePercentage: 80,
            feedbackState: AiFeedbackState.correct,
            feedbackTimestamp: DateTime.utc(2026, 7, 27),
          ),
          citations: const [
            VerifiableCitation(
              sourceEntryId: 'entry-a',
              exactQuote: 'Project planning',
              confidenceScore: .9,
              startUtf16: 0,
              endUtf16: 16,
            ),
          ],
        );

    expect(
      result.graph.nodes.singleWhere((node) => node.id == 'node-a').confidence,
      .6,
    );
    expect(result.graph.edges.single.weight, .5);
    expect(await harness.semanticStore.trustedAnchorCount(), 1);
  });

  test(
    'incorrect feedback prunes nodes and persists a negative constraint',
    () async {
      final harness = await _LearningHarness.create();
      addTearDown(harness.dispose);
      await harness.graphStore.save(_graph());
      final result =
          await GraphAdaptationEngine(
            graphStore: harness.graphStore,
            semanticStore: harness.semanticStore,
          ).apply(
            feedback: AiAccuracyFeedback(
              conclusionId: 'insight-wrong',
              confidencePercentage: 75,
              feedbackState: AiFeedbackState.incorrect,
              feedbackTimestamp: DateTime.utc(2026, 7, 27),
              correctionNote: 'Planning did not cause the delay.',
            ),
            citations: const [
              VerifiableCitation(
                sourceEntryId: 'entry-a',
                exactQuote: 'Project planning',
                confidenceScore: .9,
                startUtf16: 0,
                endUtf16: 16,
              ),
            ],
          );

      expect(
        result.graph.nodes.map((node) => node.id),
        isNot(contains('node-a')),
      );
      expect(result.graph.edges, isEmpty);
      expect(await harness.semanticStore.rejectedNodeIds(), {'node-a'});
      final constraints = await harness.semanticStore
          .recentNegativeConstraints();
      expect(
        constraints.single.correctionNote,
        'Planning did not cause the delay.',
      );
    },
  );

  test('incorrect edge feedback severs only the selected edge', () async {
    final harness = await _LearningHarness.create();
    addTearDown(harness.dispose);
    final graph = _graph();
    await harness.graphStore.save(graph);
    final edgeId = graph.edges.single.id;
    final result =
        await GraphAdaptationEngine(
          graphStore: harness.graphStore,
          semanticStore: harness.semanticStore,
        ).apply(
          feedback: AiAccuracyFeedback(
            conclusionId: 'edge-wrong',
            confidencePercentage: 70,
            feedbackState: AiFeedbackState.incorrect,
            feedbackTimestamp: DateTime.utc(2026, 7, 27),
            correctionNote: 'These themes are unrelated.',
          ),
          citations: const [],
          linkedEdgeIds: {edgeId},
        );

    expect(result.graph.nodes, hasLength(2));
    expect(result.graph.edges, isEmpty);
    expect(await harness.semanticStore.rejectedEdgeIds(), {edgeId});
  });
}

PersonalKnowledgeGraph _graph() => PersonalKnowledgeGraph(
  nodes: [
    GraphNode(
      id: 'node-a',
      type: NodeType.goal,
      label: 'Project planning',
      confidence: .5,
      evidence: [_nodeEvidence('entry-a', 'Project planning')],
    ),
    GraphNode(
      id: 'node-b',
      type: NodeType.actionItem,
      label: 'Project action',
      confidence: .6,
      evidence: [_nodeEvidence('entry-b', 'Project action')],
    ),
  ],
  edges: [
    GraphEdge(
      sourceNodeId: 'node-a',
      targetNodeId: 'node-b',
      type: EdgeType.associatedWith,
      isDirected: false,
      weight: .4,
      evidence: [
        GraphEdgeEvidence(
          entryId: 'entry-a',
          observedAt: DateTime.utc(2026, 7, 20),
          confidence: .8,
          excerpt: 'Project planning supports action',
          startUtf16: 0,
          endUtf16: 32,
        ),
      ],
    ),
  ],
);

GraphNodeEvidence _nodeEvidence(String entryId, String quote) =>
    GraphNodeEvidence(
      entryId: entryId,
      observedAt: DateTime.utc(2026, 7, 20),
      confidence: .8,
      excerpt: quote,
      startUtf16: 0,
      endUtf16: quote.length,
    );

class _LearningHarness {
  const _LearningHarness({
    required this.root,
    required this.graphStore,
    required this.semanticStore,
  });

  final Directory root;
  final PersonalKnowledgeGraphStore graphStore;
  final LocalSemanticStore semanticStore;

  static Future<_LearningHarness> create() async {
    final root = await Directory.systemTemp.createTemp('ai_learning_');
    final keyStore = InMemoryPrivateDataEncryptionKeyStore();
    return _LearningHarness(
      root: root,
      graphStore: PersonalKnowledgeGraphStore(
        storage: EncryptedJsonFileStore(
          file: File('${root.path}/graph.enc'),
          keyStore: keyStore,
        ),
        engine: PersonalKnowledgeGraphEngine(),
      ),
      semanticStore: LocalSemanticStore(
        storage: EncryptedJsonFileStore(
          file: File('${root.path}/semantic.enc'),
          keyStore: keyStore,
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await graphStore.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
