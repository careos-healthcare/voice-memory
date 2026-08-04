import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'daily_return_reason_engine.dart';
import 'early_first_signal_engine.dart';
import 'positive_pattern_engine.dart';
import 'positive_pattern_models.dart';
import 'weekly_archive_review_copy.dart';
import 'weekly_archive_review_model.dart';

/// Builds a compact weekly review from existing archive proof engines.
abstract final class WeeklyArchiveWeekReviewEngine {
  WeeklyArchiveWeekReviewEngine._();

  static const weekWindowDays = 7;
  static const minEntriesForFiveEntryGate = 5;

  static WeeklyArchiveWeekReviewResult build({
    required List<JournalEntry> entries,
    EarlyFirstSignalModel? confirmedRepeat,
    RepeatReturnCheckChangeProof? changeProof,
    bool triggerCapturedMilestone = false,
    bool helpfulActionCapturedMilestone = false,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool viewingConfirmedRepeatOrTimeline = false,
  }) {
    final reviewEntries = _reviewEntries(entries);
    final repeatSource =
        confirmedRepeat ?? EarlyFirstSignalEngine.build(entries: reviewEntries);
    final repeated = _repeatedSection(
      confirmedRepeat: repeatSource,
      entries: reviewEntries,
    );

    final changed = _changedSection(changeProof, returnChecks);
    final positivePattern = PositivePatternEngine.build(entries: entries);
    final helped = _helpedSection(positivePattern);

    final dailyReason = DailyReturnReasonEngine.build(
      entries: entries,
      changeProof: changeProof,
      triggerCapturedMilestone: triggerCapturedMilestone,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
      returnChecks: returnChecks,
      viewingConfirmedRepeatOrTimeline: viewingConfirmedRepeatOrTimeline,
    );
    final nextToWatch =
        dailyReason?.prompt ?? WeeklyArchiveWeekReviewCopy.nextToWatchFallback;
    final guidedPrompt =
        dailyReason?.guidedRecordPrompt ??
        WeeklyArchiveWeekReviewCopy.recordGuidedPrompt;

    return WeeklyArchiveWeekReviewResult(
      title: WeeklyArchiveWeekReviewCopy.title,
      promise: WeeklyArchiveWeekReviewCopy.promise,
      repeatedLine: repeated.line,
      repeatedIsFallback: repeated.isFallback,
      evidencePhrases: repeated.phrases,
      changedLine: changed.line,
      changedIsFallback: changed.isFallback,
      helpedLine: helped.line,
      helpedIsFallback: helped.isFallback,
      nextToWatchLine: nextToWatch,
      guidedRecordPrompt: guidedPrompt,
      hasRepeat: !repeated.isFallback,
      hasChange: !changed.isFallback,
      hasPositivePattern: !helped.isFallback,
    );
  }

  static List<JournalEntry> _reviewEntries(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return const [];

    final anchor = eligible.last.createdAt;
    final weekStart = anchor.subtract(const Duration(days: weekWindowDays));
    final weekEntries = eligible
        .where((entry) => !entry.createdAt.isBefore(weekStart))
        .toList();
    if (weekEntries.length >= 2) return weekEntries;

    if (eligible.length >= 3) {
      return eligible.sublist(eligible.length - 3);
    }
    return eligible;
  }

  static ({String line, bool isFallback, List<String> phrases})
  _repeatedSection({
    EarlyFirstSignalModel? confirmedRepeat,
    required List<JournalEntry> entries,
  }) {
    if (confirmedRepeat?.showsConfirmedRepeat == true) {
      final phrases = confirmedRepeat!.evidencePhrases.isNotEmpty
          ? confirmedRepeat.evidencePhrases
          : ConfirmedRepeatEvidencePhraseEngine.extract(entries).phrases;
      final line = confirmedRepeat.lines.isNotEmpty
          ? confirmedRepeat.lines.join(' ')
          : confirmedRepeat.title;
      return (line: line, isFallback: false, phrases: phrases);
    }

    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(entries);
    if (evidence.phrases.isNotEmpty) {
      return (
        line: evidence.phrases.join(', '),
        isFallback: false,
        phrases: evidence.phrases,
      );
    }

    return (
      line: WeeklyArchiveWeekReviewCopy.repeatedFallback,
      isFallback: true,
      phrases: const [],
    );
  }

  static ({String line, bool isFallback}) _changedSection(
    RepeatReturnCheckChangeProof? changeProof,
    List<RepeatReturnCheckRecord> returnChecks,
  ) {
    if (changeProof != null && changeProof.body.trim().isNotEmpty) {
      return (
        line: _weekChangeLine(changeProof.latestChoice),
        isFallback: false,
      );
    }

    final choice = RepeatReturnCheckTrendEngine.latestChoice(returnChecks);
    if (choice != null) {
      return (line: _weekChangeLine(choice), isFallback: false);
    }

    return (
      line: WeeklyArchiveWeekReviewCopy.changedFallback,
      isFallback: true,
    );
  }

  static String _weekChangeLine(RepeatReturnCheckChoice choice) =>
      switch (choice) {
        RepeatReturnCheckChoice.stronger =>
          WeeklyArchiveWeekReviewCopy.changedLouder,
        RepeatReturnCheckChoice.same => WeeklyArchiveWeekReviewCopy.changedSame,
        RepeatReturnCheckChoice.softer =>
          WeeklyArchiveWeekReviewCopy.changedSofter,
        RepeatReturnCheckChoice.changed =>
          WeeklyArchiveWeekReviewCopy.changedFallback,
      };

  static ({String line, bool isFallback}) _helpedSection(
    PositivePatternResult? positivePattern,
  ) {
    if (positivePattern != null && positivePattern.evidencePhrases.isNotEmpty) {
      final phrase = positivePattern.evidencePhrases.first
          .replaceAll('"', '')
          .trim();
      return (
        line: '${WeeklyArchiveWeekReviewCopy.helpedPrefix} $phrase',
        isFallback: false,
      );
    }
    return (line: WeeklyArchiveWeekReviewCopy.helpedFallback, isFallback: true);
  }
}
