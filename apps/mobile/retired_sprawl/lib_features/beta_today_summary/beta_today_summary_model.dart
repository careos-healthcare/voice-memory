/// Lightweight beta today summary — existing signals only.
class BetaTodaySummaryResult {
  const BetaTodaySummaryResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.summaryRows,
    required this.closingLine,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasCorrection,
    required this.hasActivePattern,
    required this.hasFadingSignal,
    required this.usesFallbackBody,
  });

  final bool shouldShow;
  final String title;
  final String body;
  final List<String> summaryRows;
  final String closingLine;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasCorrection;
  final bool hasActivePattern;
  final bool hasFadingSignal;
  final bool usesFallbackBody;
}