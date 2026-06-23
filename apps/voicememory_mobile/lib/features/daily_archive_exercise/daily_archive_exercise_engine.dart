import '../../models/journal_entry.dart';
import '../beta_feedback/beta_feedback_engine.dart';
import '../demo/sample_archive_mode.dart';
import 'daily_archive_exercise_copy.dart';
import 'daily_archive_exercise_gates.dart';
import 'daily_archive_exercise_models.dart';

/// Builds a local daily archive exercise from archive state — no uploads.
class DailyArchiveExerciseEngine {
  const DailyArchiveExerciseEngine();

  DailyArchiveExerciseResult build(DailyArchiveExerciseInput input) {
    if (input.sampleMode) {
      return _screenshotPreview();
    }

    final count = input.realSavedMomentCount;
    final kind = _kindFor(input);
    final copy = _copyFor(kind);

    return DailyArchiveExerciseResult(
      kind: kind,
      title: copy.title,
      prompt: copy.prompt,
      hint: copy.hint,
      primaryCtaLabel: copy.ctaLabel,
      primaryRoute: copy.route,
      showOnArchiveHome: DailyArchiveExerciseGates.showOnArchiveHome(
        sampleMode: false,
      ),
      showOnRecord: DailyArchiveExerciseGates.showOnRecord(sampleMode: false),
    );
  }

  int realSavedMomentCount(List<JournalEntry> entries) =>
      BetaFeedbackEngine.realEntryCountFor(entries);

  DailyArchiveExerciseResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool hasWatchTheme,
    required bool betaFeedbackCaptured,
    bool sampleMode = false,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    return build(
      DailyArchiveExerciseInput(
        realSavedMomentCount: realSavedMomentCount(
          SampleArchiveMode.excludeSampleEntries(entries),
        ),
        hasWatchTheme: hasWatchTheme,
        betaFeedbackCaptured: betaFeedbackCaptured,
        sampleMode: sampleMode,
        dayIndex: clock.day,
      ),
    );
  }

  static DailyArchiveExerciseResult _screenshotPreview() =>
      const DailyArchiveExerciseResult(
        kind: DailyArchiveExerciseKind.comparisonMaterial,
        title: DailyArchiveExerciseCopy.screenshotTitle,
        prompt: DailyArchiveExerciseCopy.screenshotPrompt,
        hint: DailyArchiveExerciseCopy.varietyHint,
        primaryCtaLabel: DailyArchiveExerciseCopy.saveMomentCta,
        primaryRoute: DailyArchiveExerciseCopy.recordRoute,
        showOnArchiveHome: false,
        showOnRecord: false,
      );

  static DailyArchiveExerciseKind _kindFor(DailyArchiveExerciseInput input) {
    final count = input.realSavedMomentCount;
    if (count <= 0) return DailyArchiveExerciseKind.firstMoment;
    if (count <= 2) return DailyArchiveExerciseKind.comparisonMaterial;
    if (input.hasWatchTheme) return DailyArchiveExerciseKind.watchTheme;
    if (count >= 3 && !input.betaFeedbackCaptured) {
      return DailyArchiveExerciseKind.betaFeedback;
    }

    const rotating = [
      DailyArchiveExerciseKind.patternRepeated,
      DailyArchiveExerciseKind.feltDifferent,
      DailyArchiveExerciseKind.checkConcern,
      DailyArchiveExerciseKind.saveUseful,
    ];
    return rotating[input.dayIndex % rotating.length];
  }

  static _DailyArchiveExerciseCopy _copyFor(DailyArchiveExerciseKind kind) {
    return switch (kind) {
      DailyArchiveExerciseKind.firstMoment => const _DailyArchiveExerciseCopy(
            title: DailyArchiveExerciseCopy.firstMomentTitle,
            prompt: DailyArchiveExerciseCopy.firstMomentPrompt,
            hint: DailyArchiveExerciseCopy.firstMomentHint,
            ctaLabel: DailyArchiveExerciseCopy.saveMomentCta,
            route: DailyArchiveExerciseCopy.recordRoute,
          ),
      DailyArchiveExerciseKind.comparisonMaterial =>
        const _DailyArchiveExerciseCopy(
          title: DailyArchiveExerciseCopy.comparisonTitle,
          prompt: DailyArchiveExerciseCopy.comparisonPrompt,
          hint: DailyArchiveExerciseCopy.comparisonHint,
          ctaLabel: DailyArchiveExerciseCopy.saveMomentCta,
          route: DailyArchiveExerciseCopy.recordRoute,
        ),
      DailyArchiveExerciseKind.watchTheme => const _DailyArchiveExerciseCopy(
            title: DailyArchiveExerciseCopy.watchThemeTitle,
            prompt: DailyArchiveExerciseCopy.watchThemePrompt,
            hint: DailyArchiveExerciseCopy.watchThemeHint,
            ctaLabel: DailyArchiveExerciseCopy.saveMomentCta,
            route: DailyArchiveExerciseCopy.recordRoute,
          ),
      DailyArchiveExerciseKind.betaFeedback => const _DailyArchiveExerciseCopy(
            title: DailyArchiveExerciseCopy.betaFeedbackTitle,
            prompt: DailyArchiveExerciseCopy.betaFeedbackPrompt,
            hint: DailyArchiveExerciseCopy.betaFeedbackHint,
            ctaLabel: DailyArchiveExerciseCopy.openBetaFeedbackCta,
            route: DailyArchiveExerciseCopy.betaFeedbackRoute,
          ),
      DailyArchiveExerciseKind.patternRepeated => const _DailyArchiveExerciseCopy(
            title: DailyArchiveExerciseCopy.varietyTitle,
            prompt: DailyArchiveExerciseCopy.patternRepeatedPrompt,
            hint: DailyArchiveExerciseCopy.varietyHint,
            ctaLabel: DailyArchiveExerciseCopy.saveMomentCta,
            route: DailyArchiveExerciseCopy.recordRoute,
          ),
      DailyArchiveExerciseKind.feltDifferent => const _DailyArchiveExerciseCopy(
            title: DailyArchiveExerciseCopy.varietyTitle,
            prompt: DailyArchiveExerciseCopy.feltDifferentPrompt,
            hint: DailyArchiveExerciseCopy.varietyHint,
            ctaLabel: DailyArchiveExerciseCopy.saveMomentCta,
            route: DailyArchiveExerciseCopy.recordRoute,
          ),
      DailyArchiveExerciseKind.checkConcern => const _DailyArchiveExerciseCopy(
            title: DailyArchiveExerciseCopy.varietyTitle,
            prompt: DailyArchiveExerciseCopy.checkConcernPrompt,
            hint: DailyArchiveExerciseCopy.varietyHint,
            ctaLabel: DailyArchiveExerciseCopy.saveMomentCta,
            route: DailyArchiveExerciseCopy.recordRoute,
          ),
      DailyArchiveExerciseKind.saveUseful => const _DailyArchiveExerciseCopy(
            title: DailyArchiveExerciseCopy.varietyTitle,
            prompt: DailyArchiveExerciseCopy.saveUsefulPrompt,
            hint: DailyArchiveExerciseCopy.varietyHint,
            ctaLabel: DailyArchiveExerciseCopy.saveMomentCta,
            route: DailyArchiveExerciseCopy.recordRoute,
          ),
    };
  }
}

class _DailyArchiveExerciseCopy {
  const _DailyArchiveExerciseCopy({
    required this.title,
    required this.prompt,
    required this.hint,
    required this.ctaLabel,
    required this.route,
  });

  final String title;
  final String prompt;
  final String hint;
  final String ctaLabel;
  final String route;
}
