import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/ai_engines/models/hypothesis_evolution.dart';
import '../../features/explainable_conclusion/explainable_conclusion.dart';
import '../../services/ai/local_semantic_store.dart';
import 'relationship_graph_models.dart';

class RelationshipDynamicsPrompt {
  const RelationshipDynamicsPrompt({
    required this.personNodeId,
    required this.personLabel,
    required this.interactions,
    required this.entryIds,
    required this.systemInstruction,
    this.activeHypotheses = const [],
  });

  final String personNodeId;
  final String personLabel;
  final List<RelationshipInteraction> interactions;
  final List<String> entryIds;
  final String systemInstruction;
  final List<HypothesisEvolution> activeHypotheses;
}

class RelationshipDynamicsReview {
  const RelationshipDynamicsReview({
    required this.personNodeId,
    required this.changeOverTime,
    required this.explainability,
  });

  final String personNodeId;
  final String changeOverTime;
  final AiExplainability explainability;

  factory RelationshipDynamicsReview.fromApiJson(Map<String, dynamic> json) {
    final conclusion = ExplainableConclusion.fromJson(json['changeOverTime']);
    final personNodeId = json['personNodeId']?.toString() ?? '';
    if (personNodeId.isEmpty ||
        conclusion == null ||
        conclusion.isLegacy ||
        conclusion.provenance.schemaVersion !=
            ExplainableConclusion.schemaVersion) {
      throw const FormatException(
        'Relationship synthesis requires a V4 conclusion.',
      );
    }
    return RelationshipDynamicsReview(
      personNodeId: personNodeId,
      changeOverTime: conclusion.statement,
      explainability: AiExplainability(
        confidence: conclusion.confidence,
        evidence: conclusion.evidence
            .map(
              (citation) => VerifiableCitation(
                sourceEntryId: citation.entryId,
                exactQuote: citation.quote,
                audioTimestampMs: citation.audioTimestampMs,
                confidenceScore: citation.confidenceScore,
                startUtf16: citation.startUtf16,
                endUtf16: citation.endUtf16,
              ),
            )
            .toList(),
        reasoning: conclusion.reasoning,
        alternativeExplanation: conclusion.alternativeExplanation.statement,
        uncertainty: conclusion.uncertainty,
        theoryId: conclusion.theoryId ?? conclusion.id,
        evolutionHistory: conclusion.evolutionHistory,
      ),
    );
  }
}

typedef RelationshipCloudSynthesizer =
    Future<RelationshipDynamicsReview> Function(
      RelationshipDynamicsPrompt prompt,
    );

class RelationshipDynamicsSynthesis {
  const RelationshipDynamicsSynthesis({
    required this.graph,
    required this.semanticStore,
    required this.cloudSynthesizer,
  });

  final PersonalKnowledgeGraph graph;
  final LocalSemanticStore semanticStore;
  final RelationshipCloudSynthesizer cloudSynthesizer;

  Future<RelationshipDynamicsReview> synthesize(GraphNode person) async {
    if (person.type != NodeType.person) {
      throw ArgumentError.value(person.type, 'person', 'Must be a person node');
    }
    final snapshot = RelationshipGraphSnapshot.forPerson(graph, person);
    if (snapshot.interactions.isEmpty) {
      throw StateError('No cited relationship interactions are available.');
    }
    final hits = await semanticStore.search(
      person.label,
      requiredTags: const {'person', 'interaction'},
      limit: 100,
    );
    final indexedEntryIds = hits.map((hit) => hit.entryId).toSet();
    final interactions = snapshot.interactions
        .where(
          (interaction) => interaction.evidence.any(
            (item) => indexedEntryIds.contains(item.entryId),
          ),
        )
        .toList();
    if (interactions.isEmpty) {
      throw StateError('No locally indexed interactions matched this person.');
    }
    final entryIds =
        interactions
            .expand((interaction) => interaction.evidence)
            .map((item) => item.entryId)
            .toSet()
            .toList()
          ..sort();
    final review = await cloudSynthesizer(
      RelationshipDynamicsPrompt(
        personNodeId: person.id,
        personLabel: person.label,
        interactions: List.unmodifiable(interactions),
        entryIds: List.unmodifiable(entryIds),
        systemInstruction: _systemInstruction,
        activeHypotheses: await semanticStore.activeHypotheses(),
      ),
    );
    _validateReview(review, person, interactions);
    final theoryId = review.explainability.theoryId;
    if (theoryId != null && review.explainability.evolutionHistory.isNotEmpty) {
      await semanticStore.upsertHypothesis(
        HypothesisEvolution(
          theoryId: theoryId,
          statement: review.changeOverTime,
          evolutionHistory: review.explainability.evolutionHistory,
        ),
      );
    }
    return review;
  }

  static RelationshipDynamicsReview localPreview(
    PersonalKnowledgeGraph graph,
    GraphNode person,
  ) {
    final snapshot = RelationshipGraphSnapshot.forPerson(graph, person);
    if (snapshot.interactions.isEmpty) {
      final evidence = person.evidence.firstOrNull;
      return RelationshipDynamicsReview(
        personNodeId: person.id,
        changeOverTime: 'More interactions are needed to describe change.',
        explainability: AiExplainability.legacy(
          sourceId: evidence?.entryId ?? person.id,
          excerpt: evidence?.excerpt,
        ),
      );
    }
    final first = snapshot.interactions.first;
    final last = snapshot.interactions.last;
    final evidence = snapshot.interactions
        .expand((interaction) => interaction.evidence)
        .map(
          (item) => VerifiableCitation(
            sourceEntryId: item.entryId,
            exactQuote: item.excerpt,
            confidenceScore: item.confidence,
            startUtf16: item.startUtf16,
            endUtf16: item.endUtf16,
          ),
        )
        .toList();
    return RelationshipDynamicsReview(
      personNodeId: person.id,
      changeOverTime:
          'The recorded emotional context moved from '
          '${first.emotion.label} toward ${last.emotion.label}.',
      explainability: AiExplainability(
        confidence: ((evidence.length / 6).clamp(.35, .9) * 100).round(),
        evidence: evidence,
        reasoning: [
          'Ordered ${snapshot.interactions.length} cited interactions by date.',
          'Compared the earliest and latest locally extracted emotions.',
        ],
        alternativeExplanation:
            'The change may reflect which moments were recorded rather than '
            'the relationship as a whole.',
        uncertainty:
            'Private interactions and unrecorded context are not represented.',
      ),
    );
  }

  static void _validateReview(
    RelationshipDynamicsReview review,
    GraphNode person,
    List<RelationshipInteraction> interactions,
  ) {
    if (review.personNodeId != person.id ||
        review.changeOverTime.trim().isEmpty) {
      throw StateError('Relationship synthesis returned the wrong subject.');
    }
    final citedEvidence = interactions
        .expand((interaction) => interaction.evidence)
        .toList();
    DateTime? previous;
    for (final citation in review.explainability.evidence) {
      final match = citedEvidence.where(
        (item) =>
            item.entryId == citation.sourceEntryId &&
            item.excerpt == citation.exactQuote &&
            (citation.startUtf16 == null ||
                item.startUtf16 == citation.startUtf16) &&
            (citation.endUtf16 == null || item.endUtf16 == citation.endUtf16),
      );
      if (match.isEmpty) {
        throw StateError(
          'Relationship synthesis returned ungrounded evidence.',
        );
      }
      final observedAt = match.first.observedAt;
      if (previous != null && observedAt.isBefore(previous)) {
        throw StateError('Relationship citations must be chronological.');
      }
      previous = observedAt;
    }
  }

  static const _systemInstruction =
      'Create a longitudinal relationship review from only the supplied '
      'interactions. Use pattern-based, epistemically humble language; never '
      'diagnose or state motives as fact. Return V4 explainability with '
      'confidence, chronological exact-quote citations carrying sourceEntryId, '
      'reasoning, an alternative explanation, and uncertainty. Every quote '
      'must be copied exactly from the supplied interaction evidence.';
}
