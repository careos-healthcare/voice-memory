/// Compact weekly archive review built from existing proof engines.
class WeeklyArchiveWeekReviewResult {
  const WeeklyArchiveWeekReviewResult({
    required this.title,
    required this.promise,
    required this.repeatedLine,
    required this.repeatedIsFallback,
    required this.changedLine, required this.changedIsFallback, required this.helpedLine, required this.helpedIsFallback, required this.nextToWatchLine, required this.guidedRecordPrompt, required this.hasRepeat, required this.hasChange, required this.hasPositivePattern, this.evidencePhrases = const [],
  });

  final String title;
  final String promise;
  final String repeatedLine;
  final bool repeatedIsFallback;
  final List<String> evidencePhrases;
  final String changedLine;
  final bool changedIsFallback;
  final String helpedLine;
  final bool helpedIsFallback;
  final String nextToWatchLine;
  final String guidedRecordPrompt;
  final bool hasRepeat;
  final bool hasChange;
  final bool hasPositivePattern;
}