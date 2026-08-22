import 'package:archiveme_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';

/// Copy for capacity decision outcomes — cautious, non-judgmental language.
abstract final class CapacityDecisionOutcomeCopy {
  CapacityDecisionOutcomeCopy._();

  static const cardTitle = 'What did you choose?';
  static const cardBody =
      'Mark what happened after the pause. This helps your archive show whether the pattern repeated or changed.';
  static const cardHelper =
      'This helps your archive understand the pattern. No private details are shared.';
  static const saveOutcomeCta = 'Save outcome';
  static const skipCta = 'Skip for now';

  static const outcomeSaidYes = 'I said yes';
  static const outcomeSaidNo = 'I said no';
  static const outcomeDelayed = 'I delayed the answer';
  static const outcomeNotSure = 'Not sure yet';

  static String labelForOutcome(String id) => switch (id) {
    CapacityDecisionOutcomeIds.saidYes => outcomeSaidYes,
    CapacityDecisionOutcomeIds.saidNo => outcomeSaidNo,
    CapacityDecisionOutcomeIds.delayed => outcomeDelayed,
    CapacityDecisionOutcomeIds.notSure => outcomeNotSure,
    _ => id,
  };

  static String outcomeMarkedCount(int count) =>
      'Outcome marked on $count moment${count == 1 ? '' : 's'}.';

  static String outcomesMarkedAfterPause(int count) =>
      'You marked $count outcome${count == 1 ? '' : 's'} after pausing.';

  static const outcomeStrengthenPrompt =
      'Mark what happened after a pause to strengthen this loop.';

  static const patternMayHaveChanged =
      'Some moments show the pattern may have changed.';

  static List<String> allVisibleStrings() => [
    cardTitle,
    cardBody,
    cardHelper,
    saveOutcomeCta,
    skipCta,
    outcomeSaidYes,
    outcomeSaidNo,
    outcomeDelayed,
    outcomeNotSure,
    outcomeStrengthenPrompt,
    patternMayHaveChanged,
  ];
}