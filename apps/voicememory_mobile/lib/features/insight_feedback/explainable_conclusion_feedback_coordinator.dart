import '../../services/app_services.dart';
import '../../services/evidence_receipt_analytics.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../explainable_conclusion/explainable_conclusion_validator.dart';
import 'insight_feedback_models.dart';
import 'insight_feedback_store.dart';

abstract final class ExplainableConclusionFeedbackCoordinator {
  ExplainableConclusionFeedbackCoordinator._();

  static Future<void> submit({
    required ValidatedExplainableConclusion conclusion,
    required InsightFeedbackChoice choice,
    required String origin,
    String? correctionNote,
  }) async {
    final value = conclusion.value;
    final trimmedCorrection = correctionNote?.trim();
    final evidenceEntryIds = value.evidence
        .map((citation) => citation.entryId)
        .toSet()
        .toList(growable: false);
    if (AppServices.isInitialized) {
      await InsightFeedbackStore.instance().saveRecord(
        InsightFeedbackRecord(
          insightId: value.id,
          insightType: InsightFeedbackType.auditableConclusion,
          choice: choice,
          createdAt: DateTime.now(),
          sourceRoute: origin,
          templateId: value.theoryId,
          conclusionKind: value.kind.name,
          evidenceEntryIds: evidenceEntryIds,
          correctionNote:
              choice == InsightFeedbackChoice.wrongAngle &&
                  trimmedCorrection?.isNotEmpty == true
              ? trimmedCorrection
              : null,
        ),
      );
    }

    final sourceTypes = value.evidence
        .map((citation) => citation.sourceType)
        .toSet();
    final sourceType = sourceTypes.length == 1
        ? sourceTypes.single.name
        : 'mixed';
    await EvidenceReceiptAnalytics.interpretationFeedbackSubmitted(
      kind: value.kind.name,
      evidenceCount: evidenceEntryIds.length,
      confidenceBand: value.confidenceBand.name,
      sourceType: sourceType,
      feedback: choice.name,
      entryCount: evidenceEntryIds.length,
      origin: origin,
      corrected:
          choice == InsightFeedbackChoice.wrongAngle &&
          trimmedCorrection?.isNotEmpty == true,
    );
    if (choice == InsightFeedbackChoice.wrongAngle ||
        choice == InsightFeedbackChoice.tooGeneric ||
        choice == InsightFeedbackChoice.hide) {
      await EvidenceReceiptAnalytics.conclusionSuppressed(
        kind: value.kind.name,
        feedback: choice.name,
        origin: origin,
      );
    }
  }
}
