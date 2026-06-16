/// Repeat recording + Day 2 return loop — copy and visibility gates.
///
/// One entry starts the archive. A second entry lets change begin to show.
/// No AI, no fake patterns, no auto-notifications.
library;

import '../first_session/two_day_activation_engine.dart';
import '../memory/memory_scope.dart';

/// Stable stage ids for analytics — fixed constants only.
abstract class RepeatRecordingNudgeStage {
  RepeatRecordingNudgeStage._();

  static const String secondEntry = 'second_entry';
  static const String day2Return = 'day2_return';
  static const String recordAgain = 'record_again';
}

/// All consumer copy — compile-time constants for test sweeps.
abstract class RepeatRecordingNudgeCopy {
  RepeatRecordingNudgeCopy._();

  static const String secondEntryTitle = 'Add one more entry';
  static const String secondEntryBody =
      'A second entry helps ArchiveMe show what changed, returned, or faded.';
  static const String secondEntryCta = 'Record again';

  static const String day2Title = 'This is where the archive starts working';
  static const String day2Body =
      'Record today and ArchiveMe can begin comparing what feels new, '
      'repeated, or quieter.';
  static const String day2BodyMemoryOff =
      'Record today to keep building your archive.';
  static const String day2Cta = 'Record today';

  static const String recordAgainCta = 'Record again';

  static const List<String> all = [
    secondEntryTitle,
    secondEntryBody,
    secondEntryCta,
    day2Title,
    day2Body,
    day2BodyMemoryOff,
    day2Cta,
    recordAgainCta,
  ];
}

/// Pure visibility gates — deterministic and unit-testable.
abstract class RepeatRecordingNudgeGates {
  RepeatRecordingNudgeGates._();

  /// Light nudge after the first save — not during the save receipt itself.
  static bool showSecondEntryNudge({
    required int entryCount,
    required bool justSaved,
    required bool hiddenThisSession,
  }) => entryCount == 1 && !justSaved && !hiddenThisSession;

  /// Day 2 return reason — next-day return with one entry, no fake comparison.
  static bool showDay2ReturnReason({
    required int entryCount,
    required TwoDayActivationPath twoDayPath,
    required bool hasRealChangeInsight,
    required bool hiddenThisSession,
  }) =>
      entryCount == 1 &&
      twoDayPath.stage == TwoDayActivationStage.dayTwoReturn &&
      !hasRealChangeInsight &&
      !hiddenThisSession;

  static String day2BodyForScope(MemoryScope scope) => scope == MemoryScope.off
      ? RepeatRecordingNudgeCopy.day2BodyMemoryOff
      : RepeatRecordingNudgeCopy.day2Body;

  /// Tiny always-available record-again affordance after the first save.
  static bool showRecordAgainCta({required int entryCount}) => entryCount >= 1;

  /// On archive, skip the tiny CTA when the first-archive value card already
  /// offers record another for exactly one entry.
  static bool showRecordAgainOnArchive({
    required int entryCount,
    required bool showingFirstArchiveValueCard,
  }) =>
      showRecordAgainCta(entryCount: entryCount) &&
      !showingFirstArchiveValueCard;
}
