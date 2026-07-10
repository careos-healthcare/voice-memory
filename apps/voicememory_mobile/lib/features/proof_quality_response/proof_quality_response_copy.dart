/// Copy for proof quality response — adapts proof surfaces to beta feedback.
abstract final class ProofQualityResponseCopy {
  ProofQualityResponseCopy._();

  static const footer =
      'Your correction changes how ArchiveMe weights the timeline.';

  // Too vague
  static const tooVagueTitle = 'Make this more specific';
  static const tooVagueBody =
      'ArchiveMe needs to show clearer evidence, not just a pattern label.';
  static const tooVagueFallback =
      'More than one saved moment pointed in the same direction.';
  static const stillTooVagueLabel = 'Still too vague';
  static const stillTooVagueFollowUp =
      'Got it. ArchiveMe will wait for more specific evidence before showing this again.';

  static const tooVagueRows = [
    'What repeated',
    'Where it returned',
    'Why ArchiveMe is showing it now',
  ];

  // Already knew this
  static const alreadyKnewTitle = 'What changed this time';
  static const alreadyKnewBody =
      'If you already knew this, the useful part is whether it changed.';
  static const alreadyKnewDeltaLine =
      'The useful part may be whether it is changing, not that it exists.';

  static const alreadyKnewRows = [
    'Did it come back stronger?',
    'Did it feel lighter?',
    'Did something help?',
    'Did you respond differently?',
    'Is it fading?',
  ];

  static const cameBackStrongerLabel = 'It came back stronger';
  static const feltLighterLabel = 'It felt lighter';
  static const somethingHelpedLabel = 'Something helped';
  static const noChangeLabel = 'No change';

  static const cameBackStrongerFollowUp =
      'Saved. ArchiveMe will treat fresh returns as stronger evidence.';
  static const feltLighterFollowUp =
      'Saved. ArchiveMe will keep this lightly in view.';
  static const somethingHelpedFollowUp =
      'Saved. ArchiveMe noted that something may have helped.';
  static const noChangeFollowUp =
      'Saved. ArchiveMe will keep this light unless it returns.';

  // Not relevant
  static const notRelevantTitle = 'Treat this as background?';
  static const notRelevantBody =
      'ArchiveMe can keep this as background unless it returns.';
  static const returnedAfterCorrectionLine =
      'This returned after you marked it as background.';

  static const keepAsBackgroundLabel = 'Keep as background';
  static const watchLightlyLabel = 'Watch lightly';
  static const relevantAgainLabel = 'Relevant again';

  static const keepAsBackgroundFollowUp =
      'Saved. ArchiveMe will keep this light unless it returns.';
  static const watchLightlyFollowUp =
      'Saved. ArchiveMe will keep this lightly in view.';
  static const relevantAgainFollowUp =
      'Saved. ArchiveMe will treat fresh returns as stronger evidence.';

  static String alreadyKnewAnswerLabel(ProofQualityAlreadyKnewAnswer answer) =>
      switch (answer) {
        ProofQualityAlreadyKnewAnswer.cameBackStronger => cameBackStrongerLabel,
        ProofQualityAlreadyKnewAnswer.feltLighter => feltLighterLabel,
        ProofQualityAlreadyKnewAnswer.somethingHelped => somethingHelpedLabel,
        ProofQualityAlreadyKnewAnswer.noChange => noChangeLabel,
      };

  static String alreadyKnewFollowUp(ProofQualityAlreadyKnewAnswer answer) =>
      switch (answer) {
        ProofQualityAlreadyKnewAnswer.cameBackStronger =>
          cameBackStrongerFollowUp,
        ProofQualityAlreadyKnewAnswer.feltLighter => feltLighterFollowUp,
        ProofQualityAlreadyKnewAnswer.somethingHelped =>
          somethingHelpedFollowUp,
        ProofQualityAlreadyKnewAnswer.noChange => noChangeFollowUp,
      };

  static String notRelevantActionLabel(ProofQualityNotRelevantAction action) =>
      switch (action) {
        ProofQualityNotRelevantAction.keepAsBackground =>
          keepAsBackgroundLabel,
        ProofQualityNotRelevantAction.watchLightly => watchLightlyLabel,
        ProofQualityNotRelevantAction.relevantAgain => relevantAgainLabel,
      };

  static String notRelevantFollowUp(ProofQualityNotRelevantAction action) =>
      switch (action) {
        ProofQualityNotRelevantAction.keepAsBackground =>
          keepAsBackgroundFollowUp,
        ProofQualityNotRelevantAction.watchLightly => watchLightlyFollowUp,
        ProofQualityNotRelevantAction.relevantAgain => relevantAgainFollowUp,
      };

  static const List<String> allVisibleStrings = [
    footer,
    tooVagueTitle,
    tooVagueBody,
    tooVagueFallback,
    stillTooVagueLabel,
    stillTooVagueFollowUp,
    ...tooVagueRows,
    alreadyKnewTitle,
    alreadyKnewBody,
    alreadyKnewDeltaLine,
    ...alreadyKnewRows,
    cameBackStrongerLabel,
    feltLighterLabel,
    somethingHelpedLabel,
    noChangeLabel,
    cameBackStrongerFollowUp,
    feltLighterFollowUp,
    somethingHelpedFollowUp,
    noChangeFollowUp,
    notRelevantTitle,
    notRelevantBody,
    returnedAfterCorrectionLine,
    keepAsBackgroundLabel,
    watchLightlyLabel,
    relevantAgainLabel,
    keepAsBackgroundFollowUp,
    watchLightlyFollowUp,
    relevantAgainFollowUp,
  ];
}

enum ProofQualityAlreadyKnewAnswer {
  cameBackStronger,
  feltLighter,
  somethingHelped,
  noChange,
}

extension ProofQualityAlreadyKnewAnswerStorage on ProofQualityAlreadyKnewAnswer {
  String get storageValue => switch (this) {
        ProofQualityAlreadyKnewAnswer.cameBackStronger => 'came_back_stronger',
        ProofQualityAlreadyKnewAnswer.feltLighter => 'felt_lighter',
        ProofQualityAlreadyKnewAnswer.somethingHelped => 'something_helped',
        ProofQualityAlreadyKnewAnswer.noChange => 'no_change',
      };

  String get analyticsValue => storageValue;
}

enum ProofQualityNotRelevantAction {
  keepAsBackground,
  watchLightly,
  relevantAgain,
}

extension ProofQualityNotRelevantActionStorage on ProofQualityNotRelevantAction {
  String get storageValue => switch (this) {
        ProofQualityNotRelevantAction.keepAsBackground => 'keep_as_background',
        ProofQualityNotRelevantAction.watchLightly => 'watch_lightly',
        ProofQualityNotRelevantAction.relevantAgain => 'relevant_again',
      };

  String get analyticsValue => storageValue;
}
