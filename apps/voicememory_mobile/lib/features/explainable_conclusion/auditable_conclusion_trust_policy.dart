import '../ai_engines/models/ai_accuracy_feedback.dart';
import '../insight_feedback/insight_feedback_models.dart';
import 'change_dimensions.dart';
import 'explainable_conclusion.dart';
import 'explainable_conclusion_validator.dart';
import 'semantic_conclusion_gate.dart';

class RankedAuditableConclusion {
  const RankedAuditableConclusion({
    required this.conclusion,
    required this.score,
    required this.wasCorrectedByUser,
    this.dimensions = const ChangeDimensions.empty(),
  });

  final ValidatedExplainableConclusion conclusion;
  final int score;
  final bool wasCorrectedByUser;

  /// The comparison that justified the claim, for the expanded detail view.
  final ChangeDimensions dimensions;
}

/// One deterministic production policy for selecting claims on Record,
/// Archive and Changes.
///
/// A candidate must clear the semantic gate before the exact-evidence
/// validator sees it, so a conclusion can never reach the UI on the strength
/// of a real quote that does not actually support it.
///
/// Feedback can suppress or reorder candidates, but it never changes the
/// candidate's evidential confidence.
abstract final class AuditableConclusionTrustPolicy {
  AuditableConclusionTrustPolicy._();

  static RankedAuditableConclusion? rankBest({
    required Iterable<ExplainableConclusion> candidates,
    required Map<String, String> canonicalTranscripts,
    Iterable<InsightFeedbackRecord> feedback = const [],
    Map<String, String?> entryThreadIds = const {},
    Set<String> userConfirmedThreadIds = const {},
    Set<String> deletedEntryIds = const {},
    Set<String> generatedTextEntryIds = const {},
  }) {
    final ranked = <RankedAuditableConclusion>[];
    for (final candidate in candidates) {
      // A comparison is a statement about movement between two moments.
      // Contradicting evidence means that movement is not settled enough to
      // present as Then/Now; keep the evidence for later reconsideration
      // rather than quietly omitting it from the receipt.
      if (candidate.kind == ExplainableInsightKind.change &&
          candidate.evidence.any(
            (citation) => citation.role == TranscriptEvidenceRole.contradicting,
          )) {
        continue;
      }
      final relevantFeedback =
          feedback
              .where(
                (record) =>
                    record.insightId == candidate.id ||
                    (candidate.theoryId?.isNotEmpty == true &&
                        record.templateId == candidate.theoryId),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = relevantFeedback.firstOrNull;
      final evidenceIds = candidate.evidence
          .map((citation) => citation.entryId)
          .toSet();
      final materiallyNew =
          latest?.hasMateriallyNewEvidence(evidenceIds) ?? false;

      if (_isSuppressed(
        candidate: candidate,
        latest: latest,
        materiallyNew: materiallyNew,
      )) {
        continue;
      }

      final correction =
          materiallyNew &&
              latest?.choice == InsightFeedbackChoice.wrongAngle &&
              latest?.correctionNote?.trim().isNotEmpty == true
          ? latest!.correctionNote!.trim()
          : null;
      final decorated = correction == null
          ? candidate
          : candidate.copyWith(
              feedbackState: AiFeedbackState.incorrect,
              feedbackTimestamp: latest!.createdAt,
              correctionNote: correction,
            );
      final semantic = SemanticConclusionGate.assess(
        conclusion: decorated,
        canonicalTranscripts: canonicalTranscripts,
        deletedEntryIds: deletedEntryIds,
        generatedTextEntryIds: generatedTextEntryIds,
        entryThreadIds: entryThreadIds,
        userConfirmedThreadIds: userConfirmedThreadIds,
        userCorrectedFraming: correction != null,
      );
      if (!semantic.isEntailed) continue;

      final gated = ExplainableConclusionRenderGate.visible(
        decorated,
        canonicalTranscripts: canonicalTranscripts,
      );
      if (gated == null) continue;

      ranked.add(
        RankedAuditableConclusion(
          conclusion: gated,
          score: _score(candidate, latest),
          wasCorrectedByUser: correction != null,
          dimensions: semantic.dimensions,
        ),
      );
    }
    ranked.sort((a, b) {
      final scoreOrder = b.score.compareTo(a.score);
      if (scoreOrder != 0) return scoreOrder;
      return a.conclusion.value.id.compareTo(b.conclusion.value.id);
    });
    return ranked.firstOrNull;
  }

  static bool _isSuppressed({
    required ExplainableConclusion candidate,
    required InsightFeedbackRecord? latest,
    required bool materiallyNew,
  }) {
    if (latest == null) return false;
    return switch (latest.choice) {
      InsightFeedbackChoice.hide => latest.insightId == candidate.id,
      InsightFeedbackChoice.wrongAngle ||
      InsightFeedbackChoice.notQuite ||
      InsightFeedbackChoice.tooEarly => !materiallyNew,
      InsightFeedbackChoice.tooGeneric => !materiallyNew,
      _ => false,
    };
  }

  static int _score(
    ExplainableConclusion candidate,
    InsightFeedbackRecord? latest,
  ) {
    final supporting = candidate.evidence
        .where((citation) => citation.role == TranscriptEvidenceRole.supporting)
        .toList(growable: false);
    final distinctSources = supporting
        .map((citation) => citation.entryId)
        .toSet()
        .length;
    final quoteSpecificity = supporting.fold<int>(
      0,
      (total, citation) => total + citation.quote.trim().length.clamp(0, 80),
    );
    final evidenceQuality = supporting.fold<double>(
      0,
      (total, citation) => total + citation.confidenceScore,
    );
    final typeFit = switch (candidate.kind) {
      ExplainableInsightKind.observation => distinctSources == 1 ? 20 : 4,
      ExplainableInsightKind.pattern => distinctSources >= 2 ? 24 : -100,
      ExplainableInsightKind.change => distinctSources >= 2 ? 28 : -100,
    };
    final usefulFraming =
        latest?.choice == InsightFeedbackChoice.accurate ||
            latest?.choice == InsightFeedbackChoice.fits
        ? 8
        : 0;
    return candidate.confidence +
        (distinctSources * 18) +
        quoteSpecificity +
        evidenceQuality.round() +
        typeFit +
        usefulFraming;
  }
}
