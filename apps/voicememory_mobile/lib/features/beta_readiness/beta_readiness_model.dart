import 'beta_readiness_copy.dart';

enum BetaReadinessItemStatus {
  pass,
  needsManualCheck,
  notAvailable;

  String get label => switch (this) {
        BetaReadinessItemStatus.pass => BetaReadinessCopy.statusPass,
        BetaReadinessItemStatus.needsManualCheck =>
          BetaReadinessCopy.statusNeedsManualCheck,
        BetaReadinessItemStatus.notAvailable =>
          BetaReadinessCopy.statusNotAvailable,
      };
}

enum BetaReadinessItemId {
  firstUseOnboardingAtZero,
  micCtaPrimary,
  typedFallbackAvailable,
  noDailyMapBeforeFirstSave,
  threeMomentsUnlockFirstProof,
  genericEntriesNoFirstProof,
  firstProofPayoffAppears,
  firstProofTruthFollowUp,
  firstProofActionLoopAfterAnswer,
  savedMomentsOpens,
  deleteMomentAvailable,
  removeFromPatternAvailable,
  correctTranscriptAvailable,
  privacyCentreOpens,
  exportLocalBackupAvailable,
  restoreLocalBackupAvailable,
  returnTomorrowCue,
  returnDayFlowAvailable,
  whatChangedAfterFourthMoment,
  sendBetaFeedbackAvailable,
  betaProgressSummaryAvailable,
  copySummaryWorks,
}

enum BetaReadinessSectionId {
  capture,
  firstProof,
  trustControls,
  returnLoop,
  betaFeedback,
  releaseWarnings,
}

class BetaReadinessItem {
  const BetaReadinessItem({
    required this.id,
    required this.label,
    required this.status,
  });

  final BetaReadinessItemId id;
  final String label;
  final BetaReadinessItemStatus status;
}

class BetaReadinessSection {
  const BetaReadinessSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final BetaReadinessSectionId id;
  final String title;
  final List<BetaReadinessItem> items;
}

class BetaReadinessWarning {
  const BetaReadinessWarning({required this.text});

  final String text;
}

class BetaReadinessReport {
  const BetaReadinessReport({
    required this.title,
    required this.intro,
    required this.sections,
    required this.warnings,
  });

  final String title;
  final String intro;
  final List<BetaReadinessSection> sections;
  final List<BetaReadinessWarning> warnings;

  List<BetaReadinessItem> get allItems =>
      sections.expand((section) => section.items).toList();

  List<String> get visibleCopyBlocks => [
        title,
        intro,
        for (final section in sections) ...[
          section.title,
          for (final item in section.items) ...[
            item.label,
            item.status.label,
          ],
        ],
        for (final warning in warnings) warning.text,
      ];
}
