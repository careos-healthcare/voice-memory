import 'return_check_payoff_model.dart';

/// Copy for the Patterns longitudinal change card — distinct from post-save payoff.
abstract final class WhatChangedSinceLastTimeCopy {
  WhatChangedSinceLastTimeCopy._();

  static const title = 'What changed since last time?';

  static const evidenceLabel = 'Compared evidence';

  static const footer =
      'ArchiveMe compares returns over time — not one answer.';

  static const softerSummary = 'This looked softer than your first proof.';

  static const strongerSummary = 'This looked stronger than your first proof.';

  static const sameSummary = 'This looked about the same as your first proof.';

  static const changedSummary = 'Something looked different this time.';

  static const unknownSummary =
      'ArchiveMe needs one more return before it can compare clearly.';

  static const firstProofRowLabel = 'First proof';

  static const latestReturnRowLabel = 'Latest return';

  static const changeRowLabel = 'Change';

  static const changeStronger = 'Stronger';

  static const changeSofter = 'Softer';

  static const changeSame = 'About the same';

  static const changeDifferent = 'Different';

  static const changeStillWatching = 'Still watching';

  static String summaryFor(ReturnCheckPayoffComparisonState state) =>
      switch (state) {
        ReturnCheckPayoffComparisonState.softer => softerSummary,
        ReturnCheckPayoffComparisonState.stronger => strongerSummary,
        ReturnCheckPayoffComparisonState.same => sameSummary,
        ReturnCheckPayoffComparisonState.changed => changedSummary,
        ReturnCheckPayoffComparisonState.unknown => unknownSummary,
      };

  static String changeValueFor(ReturnCheckPayoffComparisonState state) =>
      switch (state) {
        ReturnCheckPayoffComparisonState.softer => changeSofter,
        ReturnCheckPayoffComparisonState.stronger => changeStronger,
        ReturnCheckPayoffComparisonState.same => changeSame,
        ReturnCheckPayoffComparisonState.changed => changeDifferent,
        ReturnCheckPayoffComparisonState.unknown => changeStillWatching,
      };
}
