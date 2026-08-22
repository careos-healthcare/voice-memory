/// Archive stage for the centralized state → action map.
enum ArchiveStateActionKind {
  noEntries,
  oneEntry,
  twoUnrelated,
  twoRelated,
  firstProof,
  returnCheckUnanswered,
  returnCheckAnswered,
  patternChanged,
  helpfulActionAppeared,
  privateReportForming,
}

/// Where the canonical next action should route the user.
enum ArchiveStateActionDestination {
  recordCapture,
  patterns,
  returnCheckAnswer,
  patternsOrTimeline,
  proPreview,
}

/// Surface used to resolve context-dependent destinations.
enum ArchiveStateActionSurface { record, patterns }

/// One archive state with a single canonical action and routing target.
class ArchiveStateActionResult {
  const ArchiveStateActionResult({
    required this.kind,
    required this.actionLabel,
    required this.baseDestination,
  });

  final ArchiveStateActionKind kind;
  final String actionLabel;
  final ArchiveStateActionDestination baseDestination;

  /// Resolves routing for surfaces where destination depends on context.
  ArchiveStateActionDestination resolvedDestination({
    required ArchiveStateActionSurface surface,
    bool postSaveReturnCheckAnswerAvailable = false,
  }) {
    return switch (kind) {
      ArchiveStateActionKind.returnCheckUnanswered =>
        postSaveReturnCheckAnswerAvailable
            ? ArchiveStateActionDestination.returnCheckAnswer
            : ArchiveStateActionDestination.patterns,
      ArchiveStateActionKind.helpfulActionAppeared =>
        ArchiveStateActionDestination.patternsOrTimeline,
      ArchiveStateActionKind.privateReportForming =>
        surface == ArchiveStateActionSurface.patterns
            ? ArchiveStateActionDestination.proPreview
            : ArchiveStateActionDestination.recordCapture,
      _ => baseDestination,
    };
  }

  bool get routesToRecordCapture =>
      baseDestination == ArchiveStateActionDestination.recordCapture ||
      kind == ArchiveStateActionKind.privateReportForming;

  bool get routesToPatterns =>
      baseDestination == ArchiveStateActionDestination.patterns ||
      kind == ArchiveStateActionKind.returnCheckAnswered ||
      kind == ArchiveStateActionKind.helpfulActionAppeared;
}