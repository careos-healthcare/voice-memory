/// Copy for not-relevant recovery — user correction beats old evidence.
abstract final class NotRelevantRecoveryCopy {
  NotRelevantRecoveryCopy._();

  static const title = 'You marked this as not relevant';

  static const body =
      'ArchiveMe will treat this as background unless it returns in newer '
      'saved moments.';

  static const correctionLine =
      'Your correction changes how the timeline is weighted.';

  static const returnLine =
      'If it comes back later, ArchiveMe can show that it returned after '
      'you corrected it.';

  static const returnedAfterCorrectionLine =
      'This returned after you marked it as background.';

  static const keepAsBackgroundLabel = 'Keep as background';
  static const watchLightlyLabel = 'Watch lightly';
  static const relevantAgainLabel = 'It is relevant again';

  static const keepAsBackgroundFollowUp =
      'Saved. ArchiveMe will keep this light unless it returns.';

  static const watchLightlyFollowUp =
      'Saved. ArchiveMe will keep this lightly in view.';

  static const relevantAgainFollowUp =
      'Saved. ArchiveMe will treat fresh returns as stronger evidence.';

  static String actionLabel(NotRelevantRecoveryActionType action) =>
      switch (action) {
        NotRelevantRecoveryActionType.keepAsBackground =>
          keepAsBackgroundLabel,
        NotRelevantRecoveryActionType.watchLightly => watchLightlyLabel,
        NotRelevantRecoveryActionType.relevantAgain => relevantAgainLabel,
      };

  static String followUpFor(NotRelevantRecoveryActionType action) =>
      switch (action) {
        NotRelevantRecoveryActionType.keepAsBackground =>
          keepAsBackgroundFollowUp,
        NotRelevantRecoveryActionType.watchLightly => watchLightlyFollowUp,
        NotRelevantRecoveryActionType.relevantAgain => relevantAgainFollowUp,
      };

  static const List<String> allVisibleStrings = [
    title,
    body,
    correctionLine,
    returnLine,
    returnedAfterCorrectionLine,
    keepAsBackgroundLabel,
    watchLightlyLabel,
    relevantAgainLabel,
    keepAsBackgroundFollowUp,
    watchLightlyFollowUp,
    relevantAgainFollowUp,
  ];
}

enum NotRelevantRecoveryActionType {
  keepAsBackground,
  watchLightly,
  relevantAgain,
}

extension NotRelevantRecoveryActionTypeStorage
    on NotRelevantRecoveryActionType {
  String get storageValue => switch (this) {
        NotRelevantRecoveryActionType.keepAsBackground => 'keep_as_background',
        NotRelevantRecoveryActionType.watchLightly => 'watch_lightly',
        NotRelevantRecoveryActionType.relevantAgain => 'relevant_again',
      };

  String get analyticsValue => storageValue;
}
