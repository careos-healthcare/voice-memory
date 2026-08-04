import '../../models/journal_entry.dart';
import '../beta_feedback/beta_feedback_engine.dart';
import '../demo/sample_archive_mode.dart';
import 'archive_clarity_copy.dart';
import 'archive_clarity_gates.dart';
import 'archive_clarity_models.dart';

/// Builds local archive clarity progress from entry counts — no uploads.
class ArchiveClarityEngine {
  const ArchiveClarityEngine();

  static const reviewTargetMoments = 7;
  ArchiveClarityResult build(ArchiveClarityInput input) {
    if (input.sampleMode) {
      return _screenshotPreview();
    }

    final count = input.realSavedMomentCount.clamp(0, reviewTargetMoments);
    final usable = input.usableEvidenceCount.clamp(0, reviewTargetMoments);
    final stage = _stageFor(count);
    final copy = _copyFor(stage, input);

    return ArchiveClarityResult(
      stageId: stage,
      stageLabel: copy.stageLabel,
      headline: copy.stageLabel,
      body: copy.body,
      evidenceStrengthLabel: ArchiveClarityCopy.evidenceStrengthLabel,
      evidenceStrengthValue: ArchiveClarityCopy.evidenceStrengthValue(
        savedCount: count,
        usableCount: usable,
        target: reviewTargetMoments,
      ),
      completedUnits: count,
      targetUnits: reviewTargetMoments,
      nextStepText: copy.nextStep,
      primaryCtaLabel: copy.ctaLabel,
      primaryRoute: copy.route,
      isReviewReady: stage == ArchiveClarityStageId.reviewReady,
      isEmpty: count <= 0,
      showOnArchiveHome: ArchiveClarityGates.showOnArchiveHome(
        sampleMode: false,
      ),
    );
  }

  int realSavedMomentCount(List<JournalEntry> entries) =>
      BetaFeedbackEngine.realEntryCountFor(entries);

  ArchiveClarityResult buildFromJournal({
    required List<JournalEntry> entries,
    required int usableEvidenceCount,
    required bool hasWatchTheme,
    required bool betaFeedbackCaptured,
    bool firstWeekComplete = false,
    bool weeklyReviewAvailable = false,
    bool sampleMode = false,
  }) {
    return build(
      ArchiveClarityInput(
        realSavedMomentCount: realSavedMomentCount(
          SampleArchiveMode.excludeSampleEntries(entries),
        ),
        usableEvidenceCount: usableEvidenceCount,
        hasWatchTheme: hasWatchTheme,
        betaFeedbackCaptured: betaFeedbackCaptured,
        firstWeekComplete: firstWeekComplete,
        weeklyReviewAvailable: weeklyReviewAvailable,
        sampleMode: sampleMode,
      ),
    );
  }

  static ArchiveClarityResult _screenshotPreview() =>
      const ArchiveClarityResult(
        stageId: ArchiveClarityStageId.comparisonForming,
        stageLabel: ArchiveClarityCopy.screenshotTitle,
        headline: ArchiveClarityCopy.screenshotTitle,
        body: ArchiveClarityCopy.screenshotBody,
        evidenceStrengthLabel: ArchiveClarityCopy.evidenceStrengthLabel,
        evidenceStrengthValue: '1 of 7 moments',
        completedUnits: 1,
        targetUnits: reviewTargetMoments,
        nextStepText: ArchiveClarityCopy.comparisonNext,
        primaryCtaLabel: ArchiveClarityCopy.saveMomentCta,
        primaryRoute: ArchiveClarityCopy.recordRoute,
        isReviewReady: false,
        isEmpty: false,
        showOnArchiveHome: false,
      );

  static ArchiveClarityStageId _stageFor(int count) {
    if (count >= reviewTargetMoments) {
      return ArchiveClarityStageId.reviewReady;
    }
    if (count >= 5) return ArchiveClarityStageId.evidenceGrowing;
    if (count >= 3) return ArchiveClarityStageId.patternEmerging;
    if (count >= 1) return ArchiveClarityStageId.comparisonForming;
    return ArchiveClarityStageId.starting;
  }

  static _ArchiveClarityStageCopy _copyFor(
    ArchiveClarityStageId stage,
    ArchiveClarityInput input,
  ) {
    switch (stage) {
      case ArchiveClarityStageId.starting:
        return const _ArchiveClarityStageCopy(
          stageLabel: ArchiveClarityCopy.stageStarting,
          body: ArchiveClarityCopy.startingBody,
          nextStep: ArchiveClarityCopy.startingNext,
          ctaLabel: ArchiveClarityCopy.saveMomentCta,
          route: ArchiveClarityCopy.recordRoute,
        );
      case ArchiveClarityStageId.comparisonForming:
        return const _ArchiveClarityStageCopy(
          stageLabel: ArchiveClarityCopy.stageComparisonForming,
          body: ArchiveClarityCopy.comparisonBody,
          nextStep: ArchiveClarityCopy.comparisonNext,
          ctaLabel: ArchiveClarityCopy.saveMomentCta,
          route: ArchiveClarityCopy.recordRoute,
        );
      case ArchiveClarityStageId.patternEmerging:
        return _ArchiveClarityStageCopy(
          stageLabel: ArchiveClarityCopy.stagePatternEmerging,
          body: ArchiveClarityCopy.patternBody,
          nextStep: ArchiveClarityCopy.patternNext,
          ctaLabel: input.betaFeedbackCaptured
              ? ArchiveClarityCopy.saveMomentCta
              : ArchiveClarityCopy.openBetaFeedbackCta,
          route: input.betaFeedbackCaptured
              ? ArchiveClarityCopy.recordRoute
              : ArchiveClarityCopy.betaFeedbackRoute,
        );
      case ArchiveClarityStageId.evidenceGrowing:
        return _ArchiveClarityStageCopy(
          stageLabel: ArchiveClarityCopy.stageEvidenceGrowing,
          body: ArchiveClarityCopy.evidenceBody,
          nextStep: ArchiveClarityCopy.evidenceNext,
          ctaLabel: input.hasWatchTheme
              ? ArchiveClarityCopy.saveMomentCta
              : ArchiveClarityCopy.pickWatchThemeCta,
          route: input.hasWatchTheme
              ? ArchiveClarityCopy.recordRoute
              : ArchiveClarityCopy.archiveHomeRoute,
        );
      case ArchiveClarityStageId.reviewReady:
        return _ArchiveClarityStageCopy(
          stageLabel: ArchiveClarityCopy.stageReviewReady,
          body: ArchiveClarityCopy.reviewBody,
          nextStep: ArchiveClarityCopy.reviewNext,
          ctaLabel: ArchiveClarityCopy.weeklyReviewCta(
            weeklyReviewAvailable: input.weeklyReviewAvailable,
          ),
          route: ArchiveClarityCopy.weeklyReviewRoute(
            weeklyReviewAvailable: input.weeklyReviewAvailable,
          ),
        );
    }
  }
}

class _ArchiveClarityStageCopy {
  const _ArchiveClarityStageCopy({
    required this.stageLabel,
    required this.body,
    required this.nextStep,
    required this.ctaLabel,
    required this.route,
  });

  final String stageLabel;
  final String body;
  final String nextStep;
  final String ctaLabel;
  final String route;
}
