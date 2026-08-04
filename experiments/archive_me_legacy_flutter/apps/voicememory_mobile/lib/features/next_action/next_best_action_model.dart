/// Archive stage for the next best action line.
enum NextBestActionKind {
  noEntries,
  oneEntry,
  twoNoClearMatch,
  twoRelated,
  firstProof,
  returnCheckUnanswered,
  returnCheckAnswered,
  patternChanged,
  helpfulActionAppeared,
  privateReportForming,
}

/// One next-step guidance line — metadata only, no journal text.
class NextBestActionResult {
  const NextBestActionResult({
    required this.kind,
    required this.titleLine,
    required this.helperLine,
  });

  final NextBestActionKind kind;
  final String titleLine;
  final String helperLine;
}

/// Where the next best action may render.
enum NextBestActionSurface { record, patterns }
