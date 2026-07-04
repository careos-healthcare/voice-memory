/// One saved moment row in pattern detail — no internal ids in UI.
class PatternDetailMoment {
  const PatternDetailMoment({
    required this.entryId,
    required this.dateTimeLabel,
    required this.previewText,
    required this.statusChipLabel,
    required this.statusKey,
    this.isImportant = false,
  });

  final String entryId;
  final String dateTimeLabel;
  final String previewText;
  final String statusChipLabel;
  final String statusKey;
  final bool isImportant;
}

/// Content for the pattern detail bottom sheet.
class PatternDetailResult {
  const PatternDetailResult({
    required this.patternLabel,
    required this.evidencePhrases,
    required this.whatChangedBody,
    required this.whatChangedSupported,
    required this.whatHelpedBody,
    required this.whatHelpedSupported,
    required this.whatToWatchNextBody,
    required this.savedMoments,
  });

  final String patternLabel;
  final List<String> evidencePhrases;
  final String whatChangedBody;
  final bool whatChangedSupported;
  final String whatHelpedBody;
  final bool whatHelpedSupported;
  final String whatToWatchNextBody;
  final List<PatternDetailMoment> savedMoments;

  bool get hasSavedMoments => savedMoments.isNotEmpty;
}
