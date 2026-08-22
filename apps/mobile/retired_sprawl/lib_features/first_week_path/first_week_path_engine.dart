import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_engine.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_mode.dart';
import 'package:archiveme_mobile/features/first_week_path/first_week_path_copy.dart';
import 'package:archiveme_mobile/features/first_week_path/first_week_path_gates.dart';
import 'package:archiveme_mobile/features/first_week_path/first_week_path_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds the local first-week return path from entry counts — no uploads.
class FirstWeekPathEngine {
  const FirstWeekPathEngine();

  static const totalSteps = 7;

  FirstWeekPathResult build(FirstWeekPathInput input) {
    if (input.sampleMode) {
      return _screenshotPreview();
    }

    final count = input.realSavedMomentCount;

    if (count >= totalSteps) {
      return _completeResult(input);
    }

    if (count <= 0) {
      return FirstWeekPathResult(
        currentStep: FirstWeekPathStep.day1,
        completedStepCount: 0,
        totalStepCount: totalSteps,
        progressLabel: FirstWeekPathCopy.progressLabelStart(totalSteps),
        rewardText: '',
        nextStepText: FirstWeekPathCopy.day1Job,
        primaryCtaLabel: FirstWeekPathCopy.saveFirstMomentCta,
        primaryRoute: FirstWeekPathCopy.recordRoute,
        isComplete: false,
        cardTitle: FirstWeekPathCopy.startTitle,
        cardBody: FirstWeekPathCopy.startBody,
        showOnArchiveHome: FirstWeekPathGates.showOnArchiveHome(
          realEntryCount: 0,
          isComplete: false,
          sampleMode: false,
        ),
      );
    }

    final completed = _completedStepCount(count, input);
    final current = _currentStep(count, input);
    final reward = _rewardForCompletedStep(completed);
    final next = _nextStepText(count, input);
    final cta = _primaryCta(count, input);

    return FirstWeekPathResult(
      currentStep: current,
      completedStepCount: completed,
      totalStepCount: totalSteps,
      progressLabel: FirstWeekPathCopy.progressLabel(completed, totalSteps),
      rewardText: reward,
      nextStepText: next,
      primaryCtaLabel: cta.label,
      primaryRoute: cta.route,
      isComplete: false,
      cardTitle: FirstWeekPathCopy.cardLabel,
      cardBody: next,
      showOnArchiveHome: FirstWeekPathGates.showOnArchiveHome(
        realEntryCount: count,
        isComplete: false,
        sampleMode: false,
      ),
    );
  }

  int realSavedMomentCount(List<JournalEntry> entries) =>
      BetaFeedbackEngine.realEntryCountFor(entries);

  FirstWeekPathResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool hasWatchTheme,
    required bool betaFeedbackCaptured,
    required bool hasWeeklyReviewAvailable,
    bool sampleMode = false,
  }) {
    return build(
      FirstWeekPathInput(
        realSavedMomentCount: realSavedMomentCount(
          SampleArchiveMode.excludeSampleEntries(entries),
        ),
        hasWatchTheme: hasWatchTheme,
        betaFeedbackCaptured: betaFeedbackCaptured,
        hasWeeklyReviewAvailable: hasWeeklyReviewAvailable,
        sampleMode: sampleMode,
      ),
    );
  }

  static FirstWeekPathResult _completeResult(FirstWeekPathInput input) =>
      FirstWeekPathResult(
        currentStep: FirstWeekPathStep.day7,
        completedStepCount: totalSteps,
        totalStepCount: totalSteps,
        progressLabel: FirstWeekPathCopy.progressLabel(totalSteps, totalSteps),
        rewardText: FirstWeekPathCopy.day7Reward,
        nextStepText: FirstWeekPathCopy.day7Next,
        primaryCtaLabel: FirstWeekPathCopy.weeklyReviewCta(
          hasWeeklyReviewAvailable: input.hasWeeklyReviewAvailable,
        ),
        primaryRoute: FirstWeekPathCopy.weeklyReviewRoute(
          hasWeeklyReviewAvailable: input.hasWeeklyReviewAvailable,
        ),
        isComplete: true,
        cardTitle: FirstWeekPathCopy.completeTitle,
        cardBody: FirstWeekPathCopy.completeBody,
        showOnArchiveHome: false,
      );

  static FirstWeekPathResult _screenshotPreview() => const FirstWeekPathResult(
    currentStep: FirstWeekPathStep.day2,
    completedStepCount: 1,
    totalStepCount: totalSteps,
    progressLabel: 'Step 1 of 7 complete',
    rewardText: FirstWeekPathCopy.day1Reward,
    nextStepText: FirstWeekPathCopy.day2Next,
    primaryCtaLabel: FirstWeekPathCopy.saveMomentCta,
    primaryRoute: FirstWeekPathCopy.recordRoute,
    isComplete: false,
    cardTitle: FirstWeekPathCopy.screenshotCardTitle,
    cardBody: FirstWeekPathCopy.screenshotCardBody,
    showOnArchiveHome: false,
  );

  static int _completedStepCount(int count, FirstWeekPathInput input) {
    if (count >= totalSteps) return totalSteps;
    if (count == 3 && input.hasWatchTheme && input.betaFeedbackCaptured) {
      return 4;
    }
    return count;
  }

  static FirstWeekPathStep _currentStep(int count, FirstWeekPathInput input) {
    if (count == 3 && !input.betaFeedbackCaptured) {
      return FirstWeekPathStep.day4;
    }
    if (count == 4 && !input.hasWatchTheme) {
      return FirstWeekPathStep.day4;
    }
    if (count == 5 || count == 6) {
      return FirstWeekPathStep.day6;
    }
    return FirstWeekPathStep.values[count];
  }

  static String _rewardForCompletedStep(int completed) {
    return switch (completed) {
      1 => FirstWeekPathCopy.day1Reward,
      2 => FirstWeekPathCopy.day2Reward,
      3 => FirstWeekPathCopy.day3Reward,
      4 => FirstWeekPathCopy.day4Reward,
      5 => FirstWeekPathCopy.day5Reward,
      6 => FirstWeekPathCopy.day6Reward,
      7 => FirstWeekPathCopy.day7Reward,
      _ => '',
    };
  }

  static String _nextStepText(int count, FirstWeekPathInput input) {
    if (count == 3 && !input.betaFeedbackCaptured) {
      return FirstWeekPathCopy.day3Next;
    }
    if (count == 5) return FirstWeekPathCopy.day5Next;
    if (count == 6) return FirstWeekPathCopy.day6Next;

    return switch (count) {
      1 => FirstWeekPathCopy.day2Next,
      2 => FirstWeekPathCopy.day3Next,
      4 => FirstWeekPathCopy.day4Next,
      _ => FirstWeekPathCopy.day1Next,
    };
  }

  static _FirstWeekPathCta _primaryCta(int count, FirstWeekPathInput input) {
    if (count == 3 && !input.betaFeedbackCaptured) {
      return const _FirstWeekPathCta(
        label: FirstWeekPathCopy.openBetaFeedbackCta,
        route: FirstWeekPathCopy.betaFeedbackRoute,
      );
    }

    if (count == 4 || (count == 3 && input.hasWatchTheme)) {
      if (!input.hasWatchTheme) {
        return const _FirstWeekPathCta(
          label: FirstWeekPathCopy.pickWatchThemeCta,
          route: FirstWeekPathCopy.archiveHomeRoute,
        );
      }
      return const _FirstWeekPathCta(
        label: FirstWeekPathCopy.addThemeMomentCta,
        route: FirstWeekPathCopy.recordRoute,
      );
    }

    if (count == 5) {
      return const _FirstWeekPathCta(
        label: FirstWeekPathCopy.addThemeMomentCta,
        route: FirstWeekPathCopy.recordRoute,
      );
    }

    if (count == 6) {
      return const _FirstWeekPathCta(
        label: FirstWeekPathCopy.reviewChangesCta,
        route: FirstWeekPathCopy.archiveHomeRoute,
      );
    }

    return const _FirstWeekPathCta(
      label: FirstWeekPathCopy.saveMomentCta,
      route: FirstWeekPathCopy.recordRoute,
    );
  }
}

class _FirstWeekPathCta {
  const _FirstWeekPathCta({required this.label, required this.route});

  final String label;
  final String route;
}