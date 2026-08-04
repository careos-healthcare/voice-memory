import 'ai_accuracy_feedback.dart';
import 'hypothesis_evolution.dart';
import '../../../core/graph/graph_node.dart';
import '../../explainable_conclusion/verifiable_citation.dart';

export '../../explainable_conclusion/verifiable_citation.dart';

class ExternalExplainabilitySource {
  const ExternalExplainabilitySource({
    required this.nodeId,
    required this.source,
    required this.label,
    required this.observedAt,
  });

  final String nodeId;
  final ExternalSource source;
  final String label;
  final DateTime observedAt;
}

/// The five mandatory pillars attached to every synthesized conclusion.
class AiExplainability {
  AiExplainability({
    required this.confidence,
    required this.evidence,
    required this.reasoning,
    required this.alternativeExplanation,
    required this.uncertainty,
    this.isLegacy = false,
    this.confidenceKnown = true,
    this.accuracyFeedback,
    this.theoryId,
    this.evolutionHistory = const [],
    this.externalSources = const [],
  }) {
    if (confidence < 0 || confidence > 100) {
      throw ArgumentError.value(confidence, 'confidence', 'must be 0–100');
    }
    if (evidence.isEmpty ||
        reasoning.isEmpty ||
        alternativeExplanation.trim().isEmpty ||
        uncertainty.trim().isEmpty) {
      throw ArgumentError('All five explainability pillars are required.');
    }
  }

  final int confidence;
  final List<VerifiableCitation> evidence;
  final List<String> reasoning;
  final String alternativeExplanation;
  final String uncertainty;
  final bool isLegacy;
  final bool confidenceKnown;
  final AiAccuracyFeedback? accuracyFeedback;
  final String? theoryId;
  final List<ConfidenceSnapshot> evolutionHistory;
  final List<ExternalExplainabilitySource> externalSources;

  int get confidencePercentage => confidence;
  AiFeedbackState get feedbackState =>
      accuracyFeedback?.feedbackState ?? AiFeedbackState.pending;
  String? get correctionNote => accuracyFeedback?.correctionNote;

  AiExplainability withAccuracyFeedback(AiAccuracyFeedback feedback) =>
      AiExplainability(
        confidence: confidence,
        evidence: evidence,
        reasoning: reasoning,
        alternativeExplanation: alternativeExplanation,
        uncertainty: uncertainty,
        isLegacy: isLegacy,
        confidenceKnown: confidenceKnown,
        accuracyFeedback: feedback,
        theoryId: theoryId,
        evolutionHistory: evolutionHistory,
        externalSources: externalSources,
      );

  factory AiExplainability.legacy({required String sourceId, String? excerpt}) {
    return AiExplainability(
      confidence: 0,
      confidenceKnown: false,
      isLegacy: true,
      accuracyFeedback: AiAccuracyFeedback(
        conclusionId: 'legacy-$sourceId',
        confidencePercentage: 0,
      ),
      evidence: [
        AiEvidenceSource(
          sourceId: sourceId,
          excerpt: excerpt?.trim().isNotEmpty == true
              ? excerpt!
              : 'Source citations were not stored with this legacy synthesis.',
        ),
      ],
      reasoning: const ['Derived from older vault patterns.'],
      alternativeExplanation:
          'The older synthesis did not store a contrasting interpretation.',
      uncertainty:
          'The original synthesis did not record uncertainty or complete source context.',
    );
  }
}
