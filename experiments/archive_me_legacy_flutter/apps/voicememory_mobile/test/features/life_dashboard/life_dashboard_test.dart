import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/ai_engines/on_device_extraction_engine.dart';
import 'package:voicememory_mobile/features/life_dashboard/dashboard_aggregation_engine.dart';
import 'package:voicememory_mobile/features/life_dashboard/life_dashboard_models.dart';
import 'package:voicememory_mobile/features/life_dashboard/life_dashboard_overlay.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/hallucination_guard/hallucination_guard_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

void main() {
  late Directory root;
  late LocalSemanticStore semanticStore;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('life_dashboard_');
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

  test('aggregates today locally without requesting cloud tokens', () async {
    final graph = _graph();
    await semanticStore.upsert(
      OnDeviceExtractionResult(
        entryId: 'entry-today',
        graph: graph,
        intent: LocalEntryIntent.reflection,
        tags: const {'habit', 'goal', 'belief'},
        primaryTopics: const ['health'],
        embedding: Float32List.fromList([1, 0, 0]),
      ),
    );
    var cloudCalls = 0;
    final snapshot =
        await DashboardAggregationEngine(
          graph: graph,
          semanticStore: semanticStore,
          clock: () => DateTime.utc(2026, 7, 26, 12),
        ).aggregate(
          TimeHorizon.today,
          refreshSynthesis: (_) async {
            cloudCalls++;
            return null;
          },
        );

    expect(cloudCalls, 0);
    expect(snapshot.habits.single.label, 'Morning walk');
    expect(snapshot.goals.single.label, 'Improve health');
    expect(snapshot.identity.coreBeliefs, contains('I can be consistent'));
    expect(snapshot.dailyPulse.activeHabitTallies['Morning walk'], 1);
    expect(snapshot.dailyPulse.goalMentionFrequencies['Improve health'], 1);
    expect(snapshot.localSemanticMatches, 1);
    expect(snapshot.usedCloudSynthesis, isFalse);
  });

  test('retains cached synthesis when cloud refresh fails', () async {
    final cached = DashboardSynthesizedPayload(
      predictions: [_prediction('cached-prediction')],
    );
    final snapshot =
        await DashboardAggregationEngine(
          graph: _graph(),
          semanticStore: semanticStore,
          clock: () => DateTime.utc(2026, 7, 26),
        ).aggregate(
          TimeHorizon.thisMonth,
          cachedSynthesis: cached,
          refreshSynthesis: (_) => Future.error(StateError('offline')),
        );

    expect(snapshot.predictions.single.nodeId, 'cached-prediction');
    expect(snapshot.usedCloudSynthesis, isFalse);
  });

  test('fresh cloud synthesis replaces cached horizon payload', () async {
    final fresh = DashboardSynthesizedPayload(
      predictions: [_prediction('fresh-prediction')],
    );
    final snapshot =
        await DashboardAggregationEngine(
          graph: _graph(),
          semanticStore: semanticStore,
          clock: () => DateTime.utc(2026, 7, 26),
        ).aggregate(
          TimeHorizon.thisYear,
          cachedSynthesis: DashboardSynthesizedPayload(
            predictions: [_prediction('cached-prediction')],
          ),
          refreshSynthesis: (_) async => fresh,
        );

    expect(snapshot.predictions.single.nodeId, 'fresh-prediction');
    expect(snapshot.usedCloudSynthesis, isTrue);
  });

  testWidgets(
    'overlay switches horizons, highlights graph nodes, and opens citations',
    (tester) async {
      Set<String>? highlighted;
      final entry = JournalEntry(
        id: 'entry-today',
        createdAt: DateTime.utc(2026, 7, 26),
        transcript: 'I can be consistent',
        durationSeconds: 12,
        reflection: const Reflection(
          mood: '',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LifeDashboardOverlay(
              load: (horizon) async => _snapshot(horizon),
              onHighlightNodes: (value) => highlighted = value,
              hallucinationGuard: HallucinationGuardService(
                loadEntry: (_) async => entry,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_sections_today')), findsOneWidget);
      await tester.tap(find.text('This Month'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dashboard_sections_thisMonth')),
        findsOneWidget,
      );

      await tester.tap(find.text('Morning walk'));
      expect(highlighted, {'habit-walk'});

      await tester.tap(find.byKey(const Key('ai_explainability_expand')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('citation_entry-today')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('citation_playback_sheet')), findsOneWidget);
    },
  );
}

LifeDashboardSnapshot _snapshot(TimeHorizon horizon) => LifeDashboardSnapshot(
  horizon: horizon,
  generatedAt: DateTime.utc(2026, 7, 26),
  identity: IdentityDimension(
    coreBeliefs: ['I can be consistent'],
    selfPerceptionShifts: const [],
    nodeIds: const {'belief-consistent'},
    explainability: _explainability(),
  ),
  dailyPulse: const LocalDailyPulse(
    immediateActionItems: [],
    activeHabitTallies: {'Morning walk': 3},
    goalMentionFrequencies: {},
    emotionalVelocity: .2,
  ),
  habits: const [
    HabitTracker(
      nodeId: 'habit-walk',
      label: 'Morning walk',
      mentionCount: 3,
      sentiment: .8,
      frictionPoints: [],
      consistencyVelocity: .5,
    ),
  ],
  relationships: const [],
  goals: const [],
  predictions: const [],
  localSemanticMatches: 1,
  usedCloudSynthesis: false,
);

PredictiveHorizon _prediction(String id) => PredictiveHorizon(
  nodeId: id,
  statement: 'If the observed pattern continues, energy may improve.',
  category: 'Good week predictor',
  probability: .7,
  explainability: _explainability(),
);

AiExplainability _explainability() => AiExplainability(
  confidence: 70,
  evidence: const [
    VerifiableCitation(
      sourceEntryId: 'entry-today',
      exactQuote: 'I can be consistent',
      audioTimestampMs: 2500,
      confidenceScore: .95,
      startUtf16: 0,
      endUtf16: 19,
    ),
  ],
  reasoning: const ['The cited statement supports this dashboard lens.'],
  alternativeExplanation: 'This may describe one unusually productive day.',
  uncertainty: 'Only recorded moments are represented.',
);

PersonalKnowledgeGraph _graph() {
  final observedAt = DateTime.utc(2026, 7, 26, 8);
  final belief = _node(
    'belief-consistent',
    NodeType.belief,
    'I can be consistent',
    observedAt,
  );
  final habit = _node('habit-walk', NodeType.habit, 'Morning walk', observedAt);
  final goal = _node(
    'goal-health',
    NodeType.goal,
    'Improve health',
    observedAt,
  );
  const edgeQuote = 'Morning walk supports Improve health';
  return PersonalKnowledgeGraph(
    nodes: [belief, habit, goal],
    edges: [
      GraphEdge(
        sourceNodeId: goal.id,
        targetNodeId: habit.id,
        type: EdgeType.associatedWith,
        isDirected: false,
        weight: .9,
        evidence: [
          GraphEdgeEvidence(
            entryId: 'entry-today',
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
}

GraphNode _node(String id, NodeType type, String label, DateTime observedAt) =>
    GraphNode(
      id: id,
      type: type,
      label: label,
      confidence: .9,
      evidence: [
        GraphNodeEvidence(
          entryId: 'entry-today',
          observedAt: observedAt,
          confidence: .9,
          excerpt: label,
          startUtf16: 0,
          endUtf16: label.length,
        ),
      ],
    );
