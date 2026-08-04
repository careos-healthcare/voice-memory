import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/core/graph/graph_node.dart';
import 'package:voicememory_mobile/core/graph/personal_knowledge_graph.dart';
import 'package:voicememory_mobile/features/ai_engines/models/ai_explainability.dart';
import 'package:voicememory_mobile/features/ai_engines/on_device_extraction_engine.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart'
    as wire;
import 'package:voicememory_mobile/features/memory_graph/ui/graph_node_hero_animation.dart';
import 'package:voicememory_mobile/features/memory_graph/ui/graph_time_slider.dart';
import 'package:voicememory_mobile/features/relationships/relationship_dynamics_synthesis.dart';
import 'package:voicememory_mobile/features/relationships/relationship_evolution_sheet.dart';
import 'package:voicememory_mobile/features/relationships/relationship_graph_models.dart';
import 'package:voicememory_mobile/services/ai/local_semantic_store.dart';
import 'package:voicememory_mobile/services/hallucination_guard/hallucination_guard_service.dart';
import 'package:voicememory_mobile/storage/encrypted_json_file_store.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';
import 'package:voicememory_mobile/ui/screens/life_os/interactive_knowledge_graph_widget.dart';

void main() {
  test('local extraction emits person interaction emotion triad', () {
    const text = 'I talked with Sarah about deadlines and felt frustrated.';
    final extraction = OnDeviceExtractionEngine().extract(text: text);

    expect(
      extraction.entities.map((item) => item.type),
      containsAll([NodeType.person, NodeType.interaction, NodeType.emotion]),
    );
    expect(
      extraction.relations.map((item) => item.type),
      containsAll([EdgeType.interactedWith, EdgeType.evokedEmotion]),
    );
    expect(
      extraction.relations
          .where(
            (item) =>
                item.type == EdgeType.interactedWith ||
                item.type == EdgeType.evokedEmotion,
          )
          .every((item) => item.isExactSliceOf(text)),
      isTrue,
    );
  });

  test('temporal lens filters future relationship interactions', () {
    final graph = _relationshipGraph();
    final historical = graphAtTime(graph, DateTime.utc(2024));

    expect(
      historical.nodes.where((node) => node.type == NodeType.interaction),
      hasLength(1),
    );
    final emotionEdge = historical.edges.firstWhere(
      (edge) => edge.type == EdgeType.evokedEmotion,
    );
    expect(emotionEdge.emotionalValenceScore, -1);
    expect(
      GraphEdge.fromJson(emotionEdge.toJson()).interactionDate,
      emotionEdge.interactionDate,
    );
  });

  test('relationship synthesis enforces chronological V4 citations', () async {
    final root = await Directory.systemTemp.createTemp('relationship_graph_');
    addTearDown(() => root.delete(recursive: true));
    final graph = _relationshipGraph();
    final store = LocalSemanticStore(
      storage: EncryptedJsonFileStore(
        file: File('${root.path}/semantic.enc'),
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
      ),
    );
    for (final entryId in ['entry-old', 'entry-new']) {
      await store.upsert(
        OnDeviceExtractionResult(
          entryId: entryId,
          graph: graph,
          intent: LocalEntryIntent.emotionalProcessing,
          tags: const {'person', 'interaction', 'emotion'},
          primaryTopics: const ['relationship'],
          embedding: Float32List.fromList([1, 0, 0]),
        ),
      );
    }
    final person = graph.nodes.firstWhere(
      (node) => node.type == NodeType.person,
    );
    final synthesis = RelationshipDynamicsSynthesis(
      graph: graph,
      semanticStore: store,
      cloudSynthesizer: (prompt) async {
        expect(
          prompt.interactions.map((item) => item.occurredAt),
          orderedEquals(
            [...prompt.interactions.map((item) => item.occurredAt)]..sort(),
          ),
        );
        return RelationshipDynamicsReview(
          personNodeId: person.id,
          changeOverTime: 'The recordings suggest growing mutual trust.',
          explainability: AiExplainability(
            confidence: 82,
            evidence: [
              _citation(prompt.interactions.first.evidence.first),
              _citation(prompt.interactions.last.evidence.first),
            ],
            reasoning: const [
              'Compared the earliest and latest cited interactions.',
            ],
            alternativeExplanation:
                'Different situations may account for the emotional contrast.',
            uncertainty: 'Only recorded moments are represented.',
          ),
        );
      },
    );

    final review = await synthesis.synthesize(person);
    expect(review.explainability.evidence, hasLength(2));
    expect(review.changeOverTime, contains('mutual trust'));
  });

  test('relationship API payload maps strict V4 evidence and audio time', () {
    const quote = 'Sarah celebrated the launch';
    final conclusion = wire.ExplainableConclusion(
      id: 'relationship-sarah',
      statement: 'The recordings suggest more trust over time.',
      confidence: 82,
      reasoning: const ['Compared cited interactions in chronological order.'],
      uncertaintyNote: 'Only recorded interactions are represented.',
      evidence: [
        wire.TranscriptEvidenceCitation(
          entryId: 'entry-new',
          quote: quote,
          startUtf16: 0,
          endUtf16: quote.length,
          role: wire.TranscriptEvidenceRole.supporting,
          audioTimestampMs: 4200,
          confidenceScore: .94,
          sourceCapturedAt: DateTime.utc(2026, 1),
          sourceType: wire.EvidenceSourceType.voice,
        ),
      ],
      alternatives: const [
        wire.ExplainableAlternative(
          statement: 'The situations may simply have differed.',
          rationale: 'Context can influence emotional language.',
        ),
      ],
      provenance: wire.ExplainableConclusionProvenance(
        source: 'model',
        generatedAt: DateTime.utc(2026),
        schemaVersion: wire.ExplainableConclusion.schemaVersion,
        model: 'test-model',
        sourceRevision: 'archive-explainable-v2',
      ),
    );

    final review = RelationshipDynamicsReview.fromApiJson({
      'personNodeId': 'person-sarah',
      'changeOverTime': conclusion.toJson(),
    });

    expect(review.explainability.evidence.single.audioTimestampMs, 4200);
    expect(review.explainability.alternativeExplanation, contains('differed'));
  });

  testWidgets('time slider reports a historical cutoff and reset', (
    tester,
  ) async {
    DateTime? selected;
    var reset = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphTimeSlider(
            start: DateTime.utc(2023),
            end: DateTime.utc(2026),
            selected: DateTime.utc(2026),
            onChanged: (value) => selected = value,
            onReset: () => reset = true,
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('graph_time_slider_control')),
      const Offset(-220, 0),
    );
    await tester.pump();
    expect(selected, isNotNull);
    expect(selected!.isBefore(DateTime.utc(2026)), isTrue);
    await tester.tap(find.byKey(const Key('graph_time_slider_reset')));
    expect(reset, isTrue);
  });

  testWidgets(
    'relationship sheet renders Hero, timeline, chart, and evidence',
    (tester) async {
      final graph = _relationshipGraph();
      final person = graph.nodes.firstWhere(
        (node) => node.type == NodeType.person,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationshipEvolutionSheet(
              graph: graph,
              person: person,
              onClose: () {},
              hallucinationGuard: HallucinationGuardService(
                loadEntry: (_) async => null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('relationship_hero_${person.id}')), findsOneWidget);
      expect(
        find.byKey(const Key('relationship_valence_chart')),
        findsOneWidget,
      );
      expect(find.text('Interactions over time'), findsOneWidget);
      expect(find.byType(Hero), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('person node Hero expands into relationship evolution', (
    tester,
  ) async {
    final graph = _relationshipGraph();
    Map<String, Offset> positions = {};
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveKnowledgeGraphWidget(
            graph: graph,
            onLayoutComputed: (_, value) => positions = value,
            relationshipHallucinationGuard: HallucinationGuardService(
              loadEntry: (_) async => null,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final canvas = find.byKey(const Key('interactive-knowledge-graph-canvas'));
    await tester.tapAt(tester.getTopLeft(canvas) + positions['person-sarah']!);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('relationship_evolution_sheet')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Hero && widget.tag == graphNodeHeroTag('person-sarah'),
      ),
      findsNWidgets(2),
    );
  });
}

VerifiableCitation _citation(GraphEdgeEvidence evidence) => VerifiableCitation(
  sourceEntryId: evidence.entryId,
  exactQuote: evidence.excerpt,
  confidenceScore: evidence.confidence,
  startUtf16: evidence.startUtf16,
  endUtf16: evidence.endUtf16,
);

PersonalKnowledgeGraph _relationshipGraph() {
  final oldDate = DateTime.utc(2023, 1, 10);
  final newDate = DateTime.utc(2026, 1, 10);
  final person = GraphNode(
    id: 'person-sarah',
    type: NodeType.person,
    label: 'Sarah',
    confidence: .95,
    evidence: [
      _nodeEvidence('entry-old', oldDate, 'Sarah'),
      _nodeEvidence('entry-new', newDate, 'Sarah'),
    ],
  );
  final oldInteraction = GraphNode(
    id: 'interaction-deadlines',
    type: NodeType.interaction,
    label: 'Talked about deadlines',
    confidence: .9,
    evidence: [_nodeEvidence('entry-old', oldDate, 'talked about deadlines')],
  );
  final newInteraction = GraphNode(
    id: 'interaction-launch',
    type: NodeType.interaction,
    label: 'Celebrated the launch',
    confidence: .9,
    evidence: [_nodeEvidence('entry-new', newDate, 'celebrated the launch')],
  );
  final tense = GraphNode(
    id: 'emotion-tense',
    type: NodeType.emotion,
    label: 'tense',
    confidence: .9,
    evidence: [_nodeEvidence('entry-old', oldDate, 'tense')],
  );
  final trusted = GraphNode(
    id: 'emotion-trusted',
    type: NodeType.emotion,
    label: 'trusted',
    confidence: .9,
    evidence: [_nodeEvidence('entry-new', newDate, 'trusted')],
  );
  return PersonalKnowledgeGraph(
    nodes: [person, oldInteraction, newInteraction, tense, trusted],
    edges: [
      _edge(person, oldInteraction, oldDate, 'Sarah talked about deadlines'),
      _emotionEdge(
        oldInteraction,
        tense,
        oldDate,
        'talked about deadlines and felt tense',
        -1,
      ),
      _edge(person, newInteraction, newDate, 'Sarah celebrated the launch'),
      _emotionEdge(
        newInteraction,
        trusted,
        newDate,
        'celebrated the launch and felt trusted',
        1,
      ),
    ],
  );
}

GraphNodeEvidence _nodeEvidence(
  String entryId,
  DateTime date,
  String excerpt,
) => GraphNodeEvidence(
  entryId: entryId,
  observedAt: date,
  confidence: .9,
  excerpt: excerpt,
  startUtf16: 0,
  endUtf16: excerpt.length,
);

GraphEdge _edge(
  GraphNode person,
  GraphNode interaction,
  DateTime date,
  String excerpt,
) => GraphEdge(
  sourceNodeId: person.id,
  targetNodeId: interaction.id,
  type: EdgeType.interactedWith,
  isDirected: true,
  weight: .9,
  interactionDate: date,
  intensity: .8,
  evidence: [_edgeEvidence(interaction.evidence.single.entryId, date, excerpt)],
);

GraphEdge _emotionEdge(
  GraphNode interaction,
  GraphNode emotion,
  DateTime date,
  String excerpt,
  double valence,
) => GraphEdge(
  sourceNodeId: interaction.id,
  targetNodeId: emotion.id,
  type: EdgeType.evokedEmotion,
  isDirected: true,
  weight: .9,
  interactionDate: date,
  emotionalValenceScore: valence,
  intensity: .9,
  evidence: [_edgeEvidence(emotion.evidence.single.entryId, date, excerpt)],
);

GraphEdgeEvidence _edgeEvidence(
  String entryId,
  DateTime date,
  String excerpt,
) => GraphEdgeEvidence(
  entryId: entryId,
  observedAt: date,
  confidence: .9,
  excerpt: excerpt,
  startUtf16: 0,
  endUtf16: excerpt.length,
);
