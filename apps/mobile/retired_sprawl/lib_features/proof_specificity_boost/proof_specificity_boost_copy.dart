/// Copy for proof specificity boost — safe evidence anchors only.
abstract final class ProofSpecificityBoostCopy {
  ProofSpecificityBoostCopy._();

  static const title = 'Why this is not just a guess';

  static const body =
      'ArchiveMe is showing this because more than one saved moment pointed '
      'to the same direction.';

  static const evidenceHeading = 'The repeated signal';

  static const fallbackAnchor =
      'More than one saved moment pointed to the same pattern.';

  static const specificityRows = [
    'Seen in more than one moment',
    'Returned after the first save',
    'Strong enough to show, but still open to correction',
  ];

  static const boundaryLine =
      'This is not a label. It is a signal you can correct.';

  static const correctionPrompt = 'Does this fit?';

  static const tooVagueFollowUp =
      'Got it. ArchiveMe will need clearer evidence before making this feel strong.';

  static const notRelevantFollowUp =
      'Got it. ArchiveMe will treat this lightly unless it returns.';

  static String optionLabel(ProofSpecificityBoostAnswerType answer) =>
      switch (answer) {
        ProofSpecificityBoostAnswerType.yes => 'Yes',
        ProofSpecificityBoostAnswerType.aLittle => 'A little',
        ProofSpecificityBoostAnswerType.tooVague => 'Too vague',
        ProofSpecificityBoostAnswerType.notRelevant => 'Not relevant',
      };

  static String followUpFor(ProofSpecificityBoostAnswerType answer) =>
      switch (answer) {
        ProofSpecificityBoostAnswerType.tooVague => tooVagueFollowUp,
        ProofSpecificityBoostAnswerType.notRelevant => notRelevantFollowUp,
        ProofSpecificityBoostAnswerType.yes ||
        ProofSpecificityBoostAnswerType.aLittle =>
          'Thanks — that helps ArchiveMe stay calibrated.',
      };

  static const List<String> all = [
    title,
    body,
    evidenceHeading,
    fallbackAnchor,
    ...specificityRows,
    boundaryLine,
    correctionPrompt,
    tooVagueFollowUp,
    notRelevantFollowUp,
    'Yes',
    'A little',
    'Too vague',
    'Not relevant',
    'Thanks — that helps ArchiveMe stay calibrated.',
  ];
}

enum ProofSpecificityBoostAnswerType { yes, aLittle, tooVague, notRelevant }

extension ProofSpecificityBoostAnswerTypeStorage
    on ProofSpecificityBoostAnswerType {
  String get storageValue => switch (this) {
    ProofSpecificityBoostAnswerType.yes => 'yes',
    ProofSpecificityBoostAnswerType.aLittle => 'a_little',
    ProofSpecificityBoostAnswerType.tooVague => 'too_vague',
    ProofSpecificityBoostAnswerType.notRelevant => 'not_relevant',
  };

  String get analyticsValue => storageValue;
}