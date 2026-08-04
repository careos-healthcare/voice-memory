import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../demo/sample_archive_mode.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../early_archive/helpful_action_appeared_engine.dart';
import '../early_archive/post_save_return_check_answer_engine.dart';
import '../repeat_return_check/pattern_changed_engine.dart';
import '../repeat_return_check/repeat_return_check_change_proof.dart';
import '../repeat_return_check/repeat_return_check_copy.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import '../repeat_return_check/repeat_return_check_trend.dart';
import '../retention/second_session_signal_engine.dart';
import 'next_best_action_copy.dart';
import 'next_best_action_model.dart';

/// Selects one archive-aware next step — copy/routing only.
abstract final class NextBestActionEngine {
  NextBestActionEngine._();

  static const _signalEngine = SecondSessionSignalEngine();

  static NextBestActionResult build({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
    bool helpfulActionCapturedMilestone = false,
    bool privateReportForming = false,
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
      return const NextBestActionResult(
        kind: NextBestActionKind.helpfulActionAppeared,
        titleLine: NextBestActionCopy.helpfulActionTitle,
        helperLine: NextBestActionCopy.helpfulActionHelper,
      );
    }
    if (helpfulActionCapturedMilestone) {
      return const NextBestActionResult(
        kind: NextBestActionKind.helpfulActionAppeared,
        titleLine: NextBestActionCopy.helpfulActionTitle,
        helperLine: NextBestActionCopy.helpfulActionHelper,
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
      return const NextBestActionResult(
        kind: NextBestActionKind.patternChanged,
        titleLine: NextBestActionCopy.patternChangedTitle,
        helperLine: NextBestActionCopy.patternChangedHelper,
      );
    }

    if (_hasUnansweredReturnCheck(
      entries: realEntries,
      returnChecks: returnChecks,
    )) {
      return const NextBestActionResult(
        kind: NextBestActionKind.returnCheckUnanswered,
        titleLine: NextBestActionCopy.returnCheckUnansweredTitle,
        helperLine: NextBestActionCopy.returnCheckUnansweredHelper,
      );
    }

    if (_hasAnsweredReturnCheck(
      entries: realEntries,
      returnChecks: returnChecks,
    )) {
      return const NextBestActionResult(
        kind: NextBestActionKind.returnCheckAnswered,
        titleLine: NextBestActionCopy.returnCheckAnsweredTitle,
        helperLine: NextBestActionCopy.returnCheckAnsweredHelper,
      );
    }

    if (privateReportForming) {
      return const NextBestActionResult(
        kind: NextBestActionKind.privateReportForming,
        titleLine: NextBestActionCopy.privateReportFormingTitle,
        helperLine: NextBestActionCopy.privateReportFormingHelper,
      );
    }

    if (EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(realEntries)) {
      return const NextBestActionResult(
        kind: NextBestActionKind.firstProof,
        titleLine: NextBestActionCopy.firstProofTitle,
        helperLine: NextBestActionCopy.firstProofHelper,
      );
    }

    if (eligible.length == 2) {
      if (_signalEngine.hasGroundedRepeatMatch(eligible)) {
        return const NextBestActionResult(
          kind: NextBestActionKind.twoRelated,
          titleLine: NextBestActionCopy.twoRelatedTitle,
          helperLine: NextBestActionCopy.twoRelatedHelper,
        );
      }
      return const NextBestActionResult(
        kind: NextBestActionKind.twoNoClearMatch,
        titleLine: NextBestActionCopy.twoNoClearMatchTitle,
        helperLine: NextBestActionCopy.twoNoClearMatchHelper,
      );
    }

    if (eligible.length == 1 || count == 1) {
      return const NextBestActionResult(
        kind: NextBestActionKind.oneEntry,
        titleLine: NextBestActionCopy.oneEntryTitle,
        helperLine: NextBestActionCopy.oneEntryHelper,
      );
    }

    return const NextBestActionResult(
      kind: NextBestActionKind.noEntries,
      titleLine: NextBestActionCopy.noEntriesTitle,
      helperLine: NextBestActionCopy.noEntriesHelper,
    );
  }

  static bool _hasUnansweredReturnCheck({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
  }) =>
      PostSaveReturnCheckAnswerEngine.build(
        entries: entries,
        returnChecks: returnChecks,
      ) !=
      null;

  static bool _hasAnsweredReturnCheck({
    required List<JournalEntry> entries,
    required List<RepeatReturnCheckRecord> returnChecks,
  }) {
    if (entries.length < 4) return false;
    if (!EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries)) {
      return false;
    }
    if (!RepeatReturnCheckTrendEngine.hasAnsweredCheck(returnChecks)) {
      return false;
    }
    if (_hasUnansweredReturnCheck(
      entries: entries,
      returnChecks: returnChecks,
    )) {
      return false;
    }
    return true;
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
}
