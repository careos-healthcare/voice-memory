import '../../models/journal_entry.dart';
import '../archive_clarity/archive_clarity_engine.dart';
import '../activation/weekly_archive_review.dart';
import '../beta_feedback/beta_feedback_engine.dart';
import '../demo/sample_archive_mode.dart';
import '../archive_clarity/archive_clarity_models.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../daily_question/adaptive_daily_question_engine.dart';
import '../repeat_return_check/repeat_return_check_store.dart';
import 'todays_question_copy.dart';
import 'todays_question_gates.dart';
import 'todays_question_models.dart';

/// Builds one evidence-based Record question — no uploads, no journal text.
class TodaysQuestionEngine {
  const TodaysQuestionEngine({
    this.clarityEngine = const ArchiveClarityEngine(),
  });

  final ArchiveClarityEngine clarityEngine;

  TodaysQuestionResult build(TodaysQuestionInput input) {
    if (input.sampleMode) {
      return _screenshotPreview();
    }

    final selection = _selectionFor(input);
    return TodaysQuestionResult(
      questionId: selection.questionId,
      eyebrow: TodaysQuestionCopy.eyebrow,
      questionText: selection.questionText,
      helperText: TodaysQuestionCopy.helperText,
      primaryCtaLabel: selection.primaryCtaLabel,
      primaryRoute: selection.primaryRoute,
      suggestedCaptureMode: selection.suggestedCaptureMode,
      isEmptyState: selection.isEmptyState,
      isBetaFeedbackPrompt: selection.isBetaFeedbackPrompt,
      showOnRecord: TodaysQuestionGates.showOnRecord(sampleMode: false),
      secondaryCtaLabel: TodaysQuestionCopy.viewQuestionCta,
      secondaryRoute: TodaysQuestionCopy.route,
    );
  }

  TodaysQuestionResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool hasWatchTheme,
    required bool betaFeedbackCaptured,
    bool weeklyReviewAvailable = false,
    bool sampleMode = false,
    DateTime? now,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final count = realEntries.length;
    final usable = ArchiveEvidenceGuard.eligibleReflectionCount(realEntries);
    final clarity = clarityEngine.build(
      ArchiveClarityInput(
        realSavedMomentCount: count,
        usableEvidenceCount: usable,
        hasWatchTheme: hasWatchTheme,
        betaFeedbackCaptured: betaFeedbackCaptured,
        weeklyReviewAvailable: weeklyReviewAvailable,
      ),
    );

    final clock = now ?? DateTime.now();
    final base = build(
      TodaysQuestionInput(
        realSavedMomentCount: count,
        usableEvidenceCount: usable,
        hasWatchTheme: hasWatchTheme,
        betaFeedbackCaptured: betaFeedbackCaptured,
        archiveClarityStage: clarity.stageId,
        weeklyReviewAvailable: weeklyReviewAvailable,
        sampleMode: sampleMode,
        dayKey: clock.day + clock.month * 31,
      ),
    );

    if (sampleMode ||
        base.questionId == TodaysQuestionId.betaFeedback ||
        base.questionId == TodaysQuestionId.watchTheme ||
        base.questionId == TodaysQuestionId.reviewChange) {
      return base;
    }

    final adaptive = AdaptiveDailyQuestionEngine.build(
      entries: realEntries,
      returnChecks: RepeatReturnCheckStore.cached,
    );

    return TodaysQuestionResult(
      questionId: TodaysQuestionId.adaptive,
      eyebrow: base.eyebrow,
      questionText: adaptive.questionText,
      helperText: adaptive.helperText,
      primaryCtaLabel: base.primaryCtaLabel,
      primaryRoute: base.primaryRoute,
      suggestedCaptureMode: base.suggestedCaptureMode,
      isEmptyState: base.isEmptyState,
      isBetaFeedbackPrompt: base.isBetaFeedbackPrompt,
      showOnRecord: base.showOnRecord,
      secondaryCtaLabel: base.secondaryCtaLabel,
      secondaryRoute: base.secondaryRoute,
    );
  }

  static TodaysQuestionResult _screenshotPreview() =>
      const TodaysQuestionResult(
        questionId: TodaysQuestionId.rotated,
        eyebrow: TodaysQuestionCopy.eyebrow,
        questionText: TodaysQuestionCopy.screenshotQuestion,
        helperText: TodaysQuestionCopy.screenshotHelper,
        primaryCtaLabel: TodaysQuestionCopy.saveMomentCta,
        primaryRoute: TodaysQuestionCopy.recordRoute,
        suggestedCaptureMode: TodaysQuestionCaptureMode.any,
        isEmptyState: false,
        isBetaFeedbackPrompt: false,
        showOnRecord: false,
      );

  static _TodaysQuestionSelection _selectionFor(TodaysQuestionInput input) {
    final count = input.realSavedMomentCount;

    if (count <= 0) {
      return const _TodaysQuestionSelection(
        questionId: TodaysQuestionId.futureArchive,
        questionText: TodaysQuestionCopy.futureArchiveQuestion,
        primaryCtaLabel: TodaysQuestionCopy.saveMomentCta,
        primaryRoute: TodaysQuestionCopy.recordRoute,
        suggestedCaptureMode: TodaysQuestionCaptureMode.any,
        isEmptyState: true,
        isBetaFeedbackPrompt: false,
      );
    }

    if (input.archiveClarityStage == ArchiveClarityStageId.reviewReady) {
      return _TodaysQuestionSelection(
        questionId: TodaysQuestionId.reviewChange,
        questionText: TodaysQuestionCopy.reviewChangeQuestion,
        primaryCtaLabel: WeeklyArchiveReviewCopy.viewFullCta,
        primaryRoute: TodaysQuestionCopy.weeklyReviewRoute(
          weeklyReviewAvailable: input.weeklyReviewAvailable,
        ),
        suggestedCaptureMode: TodaysQuestionCaptureMode.voice,
        isEmptyState: false,
        isBetaFeedbackPrompt: false,
      );
    }

    if (input.hasWatchTheme && count >= 1) {
      return const _TodaysQuestionSelection(
        questionId: TodaysQuestionId.watchTheme,
        questionText: TodaysQuestionCopy.watchThemeQuestion,
        primaryCtaLabel: TodaysQuestionCopy.saveThemeEvidenceCta,
        primaryRoute: TodaysQuestionCopy.recordRoute,
        suggestedCaptureMode: TodaysQuestionCaptureMode.voice,
        isEmptyState: false,
        isBetaFeedbackPrompt: false,
      );
    }

    if (count >= 3 && !input.betaFeedbackCaptured) {
      return const _TodaysQuestionSelection(
        questionId: TodaysQuestionId.betaFeedback,
        questionText: TodaysQuestionCopy.betaFeedbackQuestion,
        primaryCtaLabel: TodaysQuestionCopy.openBetaFeedbackCta,
        primaryRoute: TodaysQuestionCopy.betaFeedbackRoute,
        suggestedCaptureMode: TodaysQuestionCaptureMode.any,
        isEmptyState: false,
        isBetaFeedbackPrompt: true,
      );
    }

    if (count <= 2) {
      return const _TodaysQuestionSelection(
        questionId: TodaysQuestionId.comparison,
        questionText: TodaysQuestionCopy.comparisonQuestion,
        primaryCtaLabel: TodaysQuestionCopy.saveComparisonCta,
        primaryRoute: TodaysQuestionCopy.recordRoute,
        suggestedCaptureMode: TodaysQuestionCaptureMode.voice,
        isEmptyState: false,
        isBetaFeedbackPrompt: false,
      );
    }

    final rotated = TodaysQuestionCopy.rotatedQuestions[
        input.dayKey % TodaysQuestionCopy.rotatedQuestions.length];
    return _TodaysQuestionSelection(
      questionId: TodaysQuestionId.rotated,
      questionText: rotated,
      primaryCtaLabel: TodaysQuestionCopy.saveMomentCta,
      primaryRoute: TodaysQuestionCopy.recordRoute,
      suggestedCaptureMode: TodaysQuestionCaptureMode.any,
      isEmptyState: false,
      isBetaFeedbackPrompt: false,
    );
  }
}

class _TodaysQuestionSelection {
  const _TodaysQuestionSelection({
    required this.questionId,
    required this.questionText,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.suggestedCaptureMode,
    required this.isEmptyState,
    required this.isBetaFeedbackPrompt,
  });

  final TodaysQuestionId questionId;
  final String questionText;
  final String primaryCtaLabel;
  final String primaryRoute;
  final TodaysQuestionCaptureMode suggestedCaptureMode;
  final bool isEmptyState;
  final bool isBetaFeedbackPrompt;
}
