/// One saved moment row in the early saved-moments review sheet.
class EarlySavedMomentPreview {
  const EarlySavedMomentPreview({
    required this.index,
    required this.label,
    required this.previewText,
    required this.savedAt,
    this.entryId,
    this.isPendingTranscript = false,
  });

  final int index;
  final String label;
  final String previewText;
  final DateTime savedAt;
  final String? entryId;
  final bool isPendingTranscript;
}

/// Content for the early saved-moments review bottom sheet.
class EarlySavedMomentsSheetContent {
  const EarlySavedMomentsSheetContent({
    required this.moments,
    required this.comparisonBody,
    required this.nextActionBody,
    required this.hasConfirmedRepeat,
    required this.hasNoClearMatch,
  });

  final List<EarlySavedMomentPreview> moments;
  final String? comparisonBody;
  final String nextActionBody;
  final bool hasConfirmedRepeat;
  final bool hasNoClearMatch;
}
