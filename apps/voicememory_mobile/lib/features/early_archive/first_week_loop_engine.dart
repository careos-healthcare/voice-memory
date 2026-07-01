import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import 'confirmed_repeat_evidence_phrase_engine.dart';
import 'early_first_signal_engine.dart';
import 'first_week_loop_copy.dart';
import 'first_week_loop_model.dart';

/// Builds the first-week return loop after first proof on Record ready state.
abstract final class FirstWeekLoopEngine {
  FirstWeekLoopEngine._();

  static FirstWeekLoop? build({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
  }) {
    if (entries.length < 3) return null;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return null;
    }
    if (RepeatReturnCheckTrendEngine.hasAnsweredCheck(returnChecks)) {
      return null;
    }

    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    final foundation = eligible.length >= 3
        ? eligible.sublist(0, 3)
        : eligible;
    final evidence = ConfirmedRepeatEvidencePhraseEngine.extract(foundation);
    if (!evidence.isStrong) return null;

    final phrase =
        ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(foundation);
    final usesPhraseBody = phrase != null &&
        ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase) &&
        !ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
          label: phrase,
          entries: foundation,
        );

    return FirstWeekLoop(
      title: FirstWeekLoopCopy.title,
      body: usesPhraseBody
          ? FirstWeekLoopCopy.bodyWithPhrase(phrase)
          : FirstWeekLoopCopy.bodyFallback,
      label: FirstWeekLoopCopy.label,
      footer: FirstWeekLoopCopy.footer,
      cta: FirstWeekLoopCopy.recordCta,
      hasPhrase: usesPhraseBody,
      hasConfirmedRepeat: true,
      usesPhraseBody: usesPhraseBody,
    );
  }
}
