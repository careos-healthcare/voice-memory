import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../demo/sample_archive_mode.dart';
import '../early_archive/confirmed_repeat_evidence_phrase_engine.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/helpful_action_appeared_engine.dart';
import '../repeat_return_check/pattern_changed_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_copy.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import '../retention/second_session_signal_engine.dart';
import 'adaptive_daily_question_copy.dart';
import 'adaptive_daily_question_model.dart';

/// Selects one archive-aware daily question — copy/routing only.
abstract final class AdaptiveDailyQuestionEngine {
  AdaptiveDailyQuestionEngine._();

  static const _signalEngine = SecondSessionSignalEngine();
  static const _maxPhraseWords = 6;

  static AdaptiveDailyQuestionResult build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool helpfulActionCapturedMilestone = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final eligible = ArchiveEvidenceGuard.eligibleEntries(realEntries);
    final count = realEntries.length;

    final helpfulAction = HelpfulActionAppearedEngine.build(
      entries: realEntries,
      returnChecks: returnChecks,
      helpfulActionCapturedMilestone: helpfulActionCapturedMilestone,
    );
    if (helpfulAction != null && helpfulAction.usesActionPhrase) {
      final actionPhrase = _groundedPhrase(
        helpfulAction.actionPhrase,
        realEntries,
      );
      return AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.helpfulActionAppeared,
        questionText: actionPhrase != null
            ? AdaptiveDailyQuestionCopy.helpfulActionQuestion(actionPhrase)
            : AdaptiveDailyQuestionCopy.helpfulActionQuestionFallback,
        helperText: AdaptiveDailyQuestionCopy.helpfulActionHelper,
        usesPhrase: actionPhrase != null,
      );
    }
    if (helpfulActionCapturedMilestone) {
      return const AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.helpfulActionAppeared,
        questionText: AdaptiveDailyQuestionCopy.helpfulActionQuestionFallback,
        helperText: AdaptiveDailyQuestionCopy.helpfulActionHelper,
      );
    }

    final changeProof = _changeProof(returnChecks);
    final patternChanged = PatternChangedEngine.build(
      changeProof: changeProof,
      records: returnChecks,
      entries: realEntries,
    );
    if (patternChanged != null &&
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(realEntries)) {
      return const AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.patternChanged,
        questionText: AdaptiveDailyQuestionCopy.patternChangedQuestion,
        helperText: AdaptiveDailyQuestionCopy.patternChangedHelper,
      );
    }

    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(realEntries) &&
        RepeatReturnCheckTrendEngine.hasAnsweredCheck(returnChecks)) {
      final returnQuestion = _returnCheckQuestion(returnChecks);
      if (returnQuestion != null) return returnQuestion;
    }

    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(realEntries)) {
      final foundation = eligible.length >= 3
          ? eligible.sublist(0, 3)
          : eligible;
      final phrase = _groundedPhrase(
        ConfirmedRepeatEvidencePhraseEngine.sharedConcretePhrase(foundation),
        foundation,
      );
      return AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.confirmedRepeat,
        questionText: phrase != null
            ? AdaptiveDailyQuestionCopy.confirmedRepeatQuestion(phrase)
            : AdaptiveDailyQuestionCopy.confirmedRepeatQuestionFallback,
        helperText: AdaptiveDailyQuestionCopy.confirmedRepeatHelper,
        usesPhrase: phrase != null,
      );
    }

    if (eligible.length == 2) {
      if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
        return const AdaptiveDailyQuestionResult(
          kind: AdaptiveDailyQuestionKind.twoRelated,
          questionText: AdaptiveDailyQuestionCopy.twoRelatedQuestion,
          helperText: AdaptiveDailyQuestionCopy.twoRelatedHelper,
        );
      }
      return const AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.twoNoClearMatch,
        questionText: AdaptiveDailyQuestionCopy.twoNoClearMatchQuestion,
        helperText: AdaptiveDailyQuestionCopy.twoNoClearMatchHelper,
      );
    }

    if (eligible.length == 1 || count == 1) {
      return const AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.oneEntry,
        questionText: AdaptiveDailyQuestionCopy.oneEntryQuestion,
        helperText: AdaptiveDailyQuestionCopy.oneEntryHelper,
      );
    }

    return const AdaptiveDailyQuestionResult(
      kind: AdaptiveDailyQuestionKind.noEntries,
      questionText: AdaptiveDailyQuestionCopy.noEntriesQuestion,
      helperText: AdaptiveDailyQuestionCopy.noEntriesHelper,
    );
  }

  static AdaptiveDailyQuestionResult? _returnCheckQuestion(
    List<RepeatReturnCheckRecord> returnChecks,
  ) {
    final latest = RepeatReturnCheckTrendEngine.latestChoice(returnChecks);
    return switch (latest) {
      RepeatReturnCheckChoice.softer => const AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.returnSofter,
        questionText: AdaptiveDailyQuestionCopy.returnSofterQuestion,
        helperText: AdaptiveDailyQuestionCopy.returnSofterHelper,
      ),
      RepeatReturnCheckChoice.stronger => const AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.returnStronger,
        questionText: AdaptiveDailyQuestionCopy.returnStrongerQuestion,
        helperText: AdaptiveDailyQuestionCopy.returnStrongerHelper,
      ),
      RepeatReturnCheckChoice.same => const AdaptiveDailyQuestionResult(
        kind: AdaptiveDailyQuestionKind.returnSame,
        questionText: AdaptiveDailyQuestionCopy.returnSameQuestion,
        helperText: AdaptiveDailyQuestionCopy.returnSameHelper,
      ),
      RepeatReturnCheckChoice.changed || null => null,
    };
  }

  static RepeatReturnCheckChangeProof? _changeProof(
    List<RepeatReturnCheckRecord> records,
  ) {
    if (!RepeatReturnCheckTrendEngine.hasAnsweredCheck(records)) return null;
    final body = RepeatReturnCheckTrendEngine.changeProofBody(records);
    final latestChoice = RepeatReturnCheckTrendEngine.latestChoice(records);
    if (body == null || latestChoice == null) return null;
    return RepeatReturnCheckChangeProof(
      title: RepeatReturnCheckCopy.changeProofTitle,
      body: body,
      latestChoice: latestChoice,
    );
  }

  static String? _groundedPhrase(String? phrase, List<JournalEntry> entries) {
    if (phrase == null || phrase.trim().isEmpty) return null;
    if (!ConfirmedRepeatEvidencePhraseEngine.isConcretePhrase(phrase)) {
      return null;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.isAbstractOnlyPhrase(phrase)) {
      return null;
    }
    if (ConfirmedRepeatEvidencePhraseEngine.usesUngroundedGenericLabel(
      label: phrase,
      entries: entries,
    )) {
      return null;
    }
    final words = phrase.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.length > _maxPhraseWords) return null;
    return phrase;
  }
}
