import '../archive_proof/visible_archive_proof_copy.dart';
import 'archive_home_summary.dart';
import 'archive_insight_feedback.dart';
import 'archive_insight_feedback_adaptation.dart';

/// Route for the local insight quality dashboard.
abstract final class InsightQualityNavigation {
  InsightQualityNavigation._();

  static const route = '/insight-quality';
}

/// Aggregate counts for the insight quality dashboard.
class InsightQualitySummary {
  const InsightQualitySummary({
    required this.feelsRightCount,
    required this.notQuiteCount,
    required this.hiddenCount,
    required this.correctionNoteCount,
  });

  final int feelsRightCount;
  final int notQuiteCount;
  final int hiddenCount;
  final int correctionNoteCount;

  bool get isEmpty =>
      feelsRightCount == 0 &&
      notQuiteCount == 0 &&
      hiddenCount == 0 &&
      correctionNoteCount == 0;
}

/// One insight target row in the dashboard.
class InsightQualityEntry {
  const InsightQualityEntry({
    required this.insightId,
    required this.label,
    required this.feelsRightCount,
    required this.notQuiteCount,
    required this.hidden,
    this.correctionNote,
    this.cautionStatus,
  });

  final String insightId;
  final String label;
  final int feelsRightCount;
  final int notQuiteCount;
  final bool hidden;
  final String? correctionNote;
  final String? cautionStatus;

  bool get hasNotQuiteFeedback => notQuiteCount > 0;
}

/// Builds local-only insight quality dashboard models.
abstract final class InsightQualityDashboardEngine {
  InsightQualityDashboardEngine._();

  static InsightQualitySummary buildSummary() => InsightQualitySummary(
    feelsRightCount: ArchiveInsightFeedbackStore.totalFeelsRightCount(),
    notQuiteCount: ArchiveInsightFeedbackStore.totalNotQuiteCount(),
    hiddenCount: ArchiveInsightFeedbackStore.hiddenInsightCount(),
    correctionNoteCount: ArchiveInsightFeedbackStore.correctionNoteCount(),
  );

  static List<InsightQualityEntry> buildEntries() {
    return ArchiveInsightFeedbackStore.allKnownInsightIds()
        .map(buildEntry)
        .toList();
  }

  static List<InsightQualityEntry> notQuiteEntries() =>
      ArchiveInsightFeedbackStore.notQuiteInsightIds()
          .map(buildEntry)
          .where((entry) => entry.hasNotQuiteFeedback)
          .toList();

  static List<InsightQualityEntry> hiddenEntries() =>
      ArchiveInsightFeedbackStore.hiddenInsightIds().map(buildEntry).toList();

  static List<InsightQualityEntry> correctionNoteEntries() =>
      ArchiveInsightFeedbackStore.correctionNoteInsightIds()
          .map(buildEntry)
          .where((entry) => entry.correctionNote != null)
          .toList();

  static InsightQualityEntry buildEntry(String insightId) {
    final target = _targetForInsightId(insightId);
    return InsightQualityEntry(
      insightId: insightId,
      label: friendlyLabel(insightId),
      feelsRightCount: ArchiveInsightFeedbackStore.feelsRightCount(insightId),
      notQuiteCount: ArchiveInsightFeedbackStore.notQuiteCount(insightId),
      hidden: ArchiveInsightFeedbackStore.isHidden(insightId),
      correctionNote: ArchiveInsightFeedbackStore.correctionNote(insightId),
      cautionStatus: target == null
          ? null
          : cautionStatusFor(
              target,
              archiveHomeStage: _archiveHomeStage(insightId),
            ),
    );
  }

  static String friendlyLabel(String insightId) {
    if (insightId.startsWith('archive_home_')) {
      final stageName = insightId.replaceFirst('archive_home_', '');
      return switch (stageName) {
        'three' => VisibleArchiveProofCopy.insightQualityLabelArchiveHomeThree,
        'four' => VisibleArchiveProofCopy.insightQualityLabelArchiveHomeFour,
        'fivePlus' =>
          VisibleArchiveProofCopy.insightQualityLabelArchiveHomeFivePlus,
        _ =>
          '${VisibleArchiveProofCopy.insightQualityLabelArchiveHome} ($stageName)',
      };
    }
    return switch (insightId) {
      'weeklyReview' => VisibleArchiveProofCopy.insightQualityLabelWeeklyReview,
      'beliefEvidence' =>
        VisibleArchiveProofCopy.insightQualityLabelBeliefEvidence,
      'beliefUpdate' => VisibleArchiveProofCopy.insightQualityLabelBeliefUpdate,
      _ => insightId,
    };
  }

  static String? cautionStatusFor(
    ArchiveInsightTarget target, {
    ArchiveHomeStage? archiveHomeStage,
  }) {
    return switch (ArchiveInsightFeedbackAdaptation.cautionLevelFor(
      target,
      archiveHomeStage: archiveHomeStage,
    )) {
      ArchiveInsightCautionLevel.none => null,
      ArchiveInsightCautionLevel.mild =>
        VisibleArchiveProofCopy.insightQualityCautionMild,
      ArchiveInsightCautionLevel.elevated =>
        VisibleArchiveProofCopy.insightQualityCautionElevated,
    };
  }

  static ArchiveInsightTarget? _targetForInsightId(String insightId) {
    if (insightId.startsWith('archive_home_')) {
      return ArchiveInsightTarget.archiveHome;
    }
    for (final target in ArchiveInsightTarget.values) {
      if (ArchiveInsightFeedbackStore.targetId(target) == insightId) {
        return target;
      }
    }
    return null;
  }

  static ArchiveHomeStage? _archiveHomeStage(String insightId) {
    if (!insightId.startsWith('archive_home_')) return null;
    final stageName = insightId.replaceFirst('archive_home_', '');
    for (final stage in ArchiveHomeStage.values) {
      if (stage.name == stageName) return stage;
    }
    return null;
  }
}
