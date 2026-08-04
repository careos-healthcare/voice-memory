import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';

class OnboardingFutureValueFixtures {
  OnboardingFutureValueFixtures._({
    required this.canonicalTranscripts,
    required this.graph,
    required this.oneMomentConclusion,
    required this.threeMomentConclusion,
    required this.fiveMomentConclusion,
  });

  static const idPrefix = 'onboarding-preview-';

  final Map<String, String> canonicalTranscripts;
  final PersonalKnowledgeGraph graph;
  final ExplainableConclusion oneMomentConclusion;
  final ExplainableConclusion threeMomentConclusion;
  final ExplainableConclusion fiveMomentConclusion;

  late final ValidatedExplainableConclusion validatedOneMoment = _validated(
    oneMomentConclusion,
  );
  late final ValidatedExplainableConclusion validatedThreeMoment = _validated(
    threeMomentConclusion,
  );
  late final ValidatedExplainableConclusion validatedFiveMoment = _validated(
    fiveMomentConclusion,
  );

  Iterable<String> get allIds sync* {
    yield* canonicalTranscripts.keys;
    yield* graph.nodes.map((node) => node.id);
    yield* graph.edges.map((edge) => edge.id);
    yield* graph.trajectories.map((trajectory) => trajectory.id);
    for (final trajectory in graph.trajectories) {
      yield* trajectory.windows.map((window) => window.id);
    }
    yield oneMomentConclusion.id;
    yield threeMomentConclusion.id;
    yield fiveMomentConclusion.id;
  }

  ValidatedExplainableConclusion _validated(ExplainableConclusion conclusion) {
    final visible = ExplainableConclusionRenderGate.visible(
      conclusion,
      canonicalTranscripts: canonicalTranscripts,
    );
    if (visible == null) {
      throw StateError('Illustrative conclusion did not pass the render gate.');
    }
    return visible;
  }

  static final OnboardingFutureValueFixtures sample = _build();

  static OnboardingFutureValueFixtures _build() {
    const transcripts = <String, String>{
      '${idPrefix}entry-1':
          'After lunch, I paused before replying to the Atlas project thread. '
          'I felt calmer.',
      '${idPrefix}entry-2':
          'I paused before replying to Maya about Atlas, then wrote down the '
          'decision first.',
      '${idPrefix}entry-3':
          'Before the Atlas check-in, I paused, wrote the decision, and sent a '
          'shorter reply.',
      '${idPrefix}entry-4':
          'I felt calm after pausing before the Atlas update and choosing the '
          'smaller scope.',
      '${idPrefix}entry-5':
          'Writing the decision before replying led to a clearer Atlas plan and '
          'one fewer follow-up.',
    };
    final dates = <String, DateTime>{
      for (var i = 1; i <= 5; i++)
        '$idPrefix'
            'entry-$i': DateTime.utc(
          2026,
          1,
          i,
          9,
        ),
    };

    GraphNodeEvidence nodeEvidence(
      String entryId,
      String quote,
      double confidence,
    ) {
      final text = transcripts[entryId]!;
      final start = text.indexOf(quote);
      if (start < 0) throw StateError('Fixture quote is not exact: $quote');
      return GraphNodeEvidence(
        entryId: entryId,
        observedAt: dates[entryId]!,
        confidence: confidence,
        excerpt: quote,
        startUtf16: start,
        endUtf16: start + quote.length,
      );
    }

    GraphEdgeEvidence edgeEvidence(
      String entryId,
      String quote,
      double confidence,
    ) {
      final node = nodeEvidence(entryId, quote, confidence);
      return GraphEdgeEvidence(
        entryId: node.entryId,
        observedAt: node.observedAt,
        confidence: node.confidence,
        excerpt: node.excerpt,
        startUtf16: node.startUtf16,
        endUtf16: node.endUtf16,
      );
    }

    TranscriptEvidenceCitation citation(
      String entryId,
      String quote, {
      TranscriptEvidenceRole role = TranscriptEvidenceRole.supporting,
    }) {
      final text = transcripts[entryId]!;
      final start = text.indexOf(quote);
      if (start < 0) throw StateError('Fixture quote is not exact: $quote');
      return TranscriptEvidenceCitation(
        entryId: entryId,
        quote: quote,
        startUtf16: start,
        endUtf16: start + quote.length,
        role: role,
        sourceCapturedAt: dates[entryId],
        sourceType: EvidenceSourceType.text,
      );
    }

    const projectId = '${idPrefix}node-project-atlas';
    const habitId = '${idPrefix}node-habit-pause';
    const emotionId = '${idPrefix}node-emotion-calm';
    const decisionId = '${idPrefix}node-decision-smaller-scope';
    const outcomeId = '${idPrefix}node-outcome-clearer-plan';

    final nodes = <GraphNode>[
      GraphNode(
        id: projectId,
        type: NodeType.project,
        label: 'Atlas project',
        confidence: 0.9,
        evidence: [
          nodeEvidence('${idPrefix}entry-1', 'Atlas project', 0.9),
          nodeEvidence('${idPrefix}entry-5', 'Atlas plan', 0.82),
        ],
      ),
      GraphNode(
        id: habitId,
        type: NodeType.habit,
        label: 'Pause before replying',
        confidence: 0.78,
        evidence: [
          nodeEvidence('${idPrefix}entry-1', 'paused before replying', 0.54),
          nodeEvidence('${idPrefix}entry-2', 'paused before replying', 0.68),
          nodeEvidence('${idPrefix}entry-3', 'paused', 0.72),
          nodeEvidence(
            '${idPrefix}entry-4',
            'pausing before the Atlas update',
            0.78,
          ),
        ],
      ),
      GraphNode(
        id: emotionId,
        type: NodeType.emotion,
        label: 'Calm',
        confidence: 0.76,
        evidence: [
          nodeEvidence('${idPrefix}entry-1', 'felt calmer', 0.7),
          nodeEvidence('${idPrefix}entry-4', 'felt calm', 0.76),
        ],
      ),
      GraphNode(
        id: decisionId,
        type: NodeType.decision,
        label: 'Choose smaller scope',
        confidence: 0.75,
        evidence: [
          nodeEvidence(
            '${idPrefix}entry-4',
            'choosing the smaller scope',
            0.75,
          ),
        ],
      ),
      GraphNode(
        id: outcomeId,
        type: NodeType.outcome,
        label: 'Clearer plan',
        confidence: 0.8,
        evidence: [
          nodeEvidence('${idPrefix}entry-5', 'a clearer Atlas plan', 0.8),
        ],
      ),
    ];

    final edges = <GraphEdge>[
      GraphEdge(
        id: '${idPrefix}edge-habit-project',
        sourceNodeId: habitId,
        targetNodeId: projectId,
        type: EdgeType.associatedWith,
        isDirected: false,
        weight: 0.78,
        evidence: [
          edgeEvidence(
            '${idPrefix}entry-1',
            'paused before replying to the Atlas project thread',
            0.78,
          ),
        ],
      ),
      GraphEdge(
        id: '${idPrefix}edge-habit-emotion',
        sourceNodeId: habitId,
        targetNodeId: emotionId,
        type: EdgeType.resultedIn,
        isDirected: true,
        weight: 0.7,
        evidence: [
          edgeEvidence(
            '${idPrefix}entry-1',
            'I paused before replying to the Atlas project thread. I felt calmer',
            0.7,
          ),
        ],
      ),
      GraphEdge(
        id: '${idPrefix}edge-habit-decision',
        sourceNodeId: habitId,
        targetNodeId: decisionId,
        type: EdgeType.influences,
        isDirected: true,
        weight: 0.72,
        evidence: [
          edgeEvidence(
            '${idPrefix}entry-4',
            'pausing before the Atlas update and choosing the smaller scope',
            0.72,
          ),
        ],
      ),
      GraphEdge(
        id: '${idPrefix}edge-decision-outcome',
        sourceNodeId: decisionId,
        targetNodeId: outcomeId,
        type: EdgeType.resultedIn,
        isDirected: true,
        weight: 0.8,
        evidence: [
          edgeEvidence(
            '${idPrefix}entry-5',
            'Writing the decision before replying led to a clearer Atlas plan',
            0.8,
          ),
        ],
      ),
    ];

    final habitTrajectory = GraphTrajectory(
      id: '${idPrefix}trajectory-habit',
      type: GraphTrajectoryType.habitFrequency,
      subjectNodeId: habitId,
      windows: [
        for (var i = 0; i < nodes[1].evidence.length; i++)
          GraphTrajectoryWindow(
            id: '${idPrefix}window-habit-${i + 1}',
            start: nodes[1].evidence[i].observedAt,
            end: nodes[1].evidence[i].observedAt,
            value: i + 1,
            label: 'Illustrative habit occurrence',
            evidence: [nodes[1].evidence[i]],
          ),
      ],
    );

    final provenance = ExplainableConclusionProvenance(
      source: 'illustrative-fixture',
      generatedAt: DateTime.utc(2026, 1, 6),
      schemaVersion: ExplainableConclusion.schemaVersion,
      model: 'none',
      sourceRevision: 'onboarding-preview-v1',
    );
    const alternative = ExplainableAlternative(
      statement: 'The shorter replies may be specific to the Atlas project.',
      rationale:
          'All fictional examples concern one project, so the behavior may not '
          'carry into other contexts.',
      confidence: 38,
    );

    final one = ExplainableConclusion(
      id: '${idPrefix}conclusion-1',
      statement:
          'This fictional moment suggests a possible pause-before-replying habit.',
      confidence: 45,
      reasoning: const [
        'One exact phrase describes pausing before a reply.',
        'One example can suggest a possibility but cannot establish recurrence.',
      ],
      uncertaintyNote:
          'One moment cannot show whether this behavior repeats or what affects it.',
      evidence: [citation('${idPrefix}entry-1', 'paused before replying')],
      alternatives: const [alternative],
      provenance: provenance,
      historyVersion: 1,
    );
    final three = ExplainableConclusion(
      id: '${idPrefix}conclusion-3',
      statement:
          'Across these fictional moments, pausing before replying appears before '
          'a more deliberate response.',
      confidence: 72,
      reasoning: const [
        'Three fictional moments repeat the same pause-before-replying phrase.',
        'Each pause occurs before a more deliberate response.',
      ],
      uncertaintyNote:
          'Three related moments are still a small sample from one fictional project.',
      evidence: [
        citation('${idPrefix}entry-1', 'paused before replying'),
        citation('${idPrefix}entry-2', 'paused before replying'),
        citation(
          '${idPrefix}entry-3',
          'paused, wrote the decision, and sent a shorter reply',
        ),
      ],
      alternatives: const [alternative],
      provenance: provenance,
      historyVersion: 2,
    );
    final five = ExplainableConclusion(
      id: '${idPrefix}conclusion-5',
      statement:
          'In this fictional sequence, pausing and writing the decision first '
          'often precede a smaller scope or clearer reply.',
      confidence: 82,
      reasoning: const [
        'The sequence repeats across four cited fictional moments.',
        'Pausing and writing occur before the smaller scope or clearer reply.',
      ],
      uncertaintyNote:
          'The entries are related and illustrative; unrelated or vague real '
          'entries might support no conclusion.',
      evidence: [
        citation('${idPrefix}entry-1', 'paused before replying'),
        citation('${idPrefix}entry-2', 'wrote down the decision first'),
        citation(
          '${idPrefix}entry-4',
          'pausing before the Atlas update and choosing the smaller scope',
        ),
        citation(
          '${idPrefix}entry-5',
          'Writing the decision before replying led to a clearer Atlas plan',
        ),
      ],
      alternatives: const [alternative],
      provenance: provenance,
      historyVersion: 3,
    );

    return OnboardingFutureValueFixtures._(
      canonicalTranscripts: transcripts,
      graph: PersonalKnowledgeGraph(
        schemaVersion: 2,
        nodes: nodes,
        edges: edges,
        trajectories: [habitTrajectory],
        materialization: GraphMaterializationMetadata(
          processedEntryRevisions: {
            for (final id in transcripts.keys) id: '${idPrefix}revision-1',
          },
          extractorVersion: '${idPrefix}illustrative',
          governanceVersion: '${idPrefix}illustrative',
          governanceHash: '${idPrefix}illustrative',
          materializedAt: DateTime.utc(2026, 1, 6),
        ),
      ),
      oneMomentConclusion: one,
      threeMomentConclusion: three,
      fiveMomentConclusion: five,
    );
  }
}
