import '../archive_proof/visible_archive_proof_copy.dart';
import 'archive_home_summary.dart';
import 'archive_insight_feedback.dart';

/// How much to soften insight copy after local negative feedback.
enum ArchiveInsightCautionLevel {
  none,
  mild,
  elevated,
}

/// User-facing copy when insights adapt to local feedback.
abstract final class ArchiveInsightFeedbackAdaptationCopy {
  static const stillTestingBelief =
      VisibleArchiveProofCopy.insightAdaptationStillTestingBelief;

  static const mayNotBeQuiteRight =
      VisibleArchiveProofCopy.insightAdaptationMayNotBeQuiteRight;

  static const needsAnotherMoment =
      VisibleArchiveProofCopy.insightAdaptationNeedsAnotherMoment;

  static const savedUsefulFeedback =
      VisibleArchiveProofCopy.insightAdaptationSavedUsefulFeedback;
}

/// Resolves local feedback into cautious copy and suppress rules.
abstract final class ArchiveInsightFeedbackAdaptation {
  ArchiveInsightFeedbackAdaptation._();

  static String resolveInsightId(
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) {
    switch (target) {
      case ArchiveInsightTarget.archiveHome:
        return ArchiveInsightFeedbackStore.archiveHomeId(
          archiveHomeStage ?? ArchiveHomeStage.three,
        );
      case ArchiveInsightTarget.weeklyReview:
      case ArchiveInsightTarget.beliefEvidence:
      case ArchiveInsightTarget.beliefUpdate:
        return ArchiveInsightFeedbackStore.targetId(target);
    }
  }

  static bool shouldSuppress(
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) =>
      ArchiveInsightFeedbackStore.isHidden(
        resolveInsightId(target, archiveHomeStage: archiveHomeStage),
      );

  static bool hasNegativeFeedback(
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) =>
      ArchiveInsightFeedbackStore.notQuiteCount(
        resolveInsightId(target, archiveHomeStage: archiveHomeStage),
      ) >
      0;

  static bool hasPositiveFeedback(
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) =>
      ArchiveInsightFeedbackStore.feelsRightCount(
        resolveInsightId(target, archiveHomeStage: archiveHomeStage),
      ) >
      0;

  static ArchiveInsightCautionLevel cautionLevelFor(
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) {
    final count = ArchiveInsightFeedbackStore.notQuiteCount(
      resolveInsightId(target, archiveHomeStage: archiveHomeStage),
    );
    if (count >= 2) return ArchiveInsightCautionLevel.elevated;
    if (count >= 1) return ArchiveInsightCautionLevel.mild;
    return ArchiveInsightCautionLevel.none;
  }

  static String? cautionLineFor(
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) {
    final level = cautionLevelFor(target, archiveHomeStage: archiveHomeStage);
    return switch (level) {
      ArchiveInsightCautionLevel.none => null,
      ArchiveInsightCautionLevel.elevated =>
        ArchiveInsightFeedbackAdaptationCopy.stillTestingBelief,
      ArchiveInsightCautionLevel.mild => switch (target) {
          ArchiveInsightTarget.beliefEvidence ||
          ArchiveInsightTarget.beliefUpdate =>
            ArchiveInsightFeedbackAdaptationCopy.needsAnotherMoment,
          _ => ArchiveInsightFeedbackAdaptationCopy.mayNotBeQuiteRight,
        },
    };
  }

  static String adaptedCopyFor(
    String baseCopy,
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) {
    final cautionLine = cautionLineFor(
      target,
      archiveHomeStage: archiveHomeStage,
    );
    if (cautionLine == null || baseCopy.startsWith(cautionLine)) {
      return baseCopy;
    }
    return '$cautionLine\n\n$baseCopy';
  }
}
