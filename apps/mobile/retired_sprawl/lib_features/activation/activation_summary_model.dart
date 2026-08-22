/// Read-only activation health snapshot for internal/debug use.
class ActivationSummary {
  const ActivationSummary({
    required this.firstPatternCorrectionCount,
    required this.firstPatternQualityWeak,
    required this.watchForPromptShownCount,
    required this.watchForPromptAcceptedCount,
    required this.returnCaptureQuickAnswerSelectedCount, required this.returnCaptureRecordedAfterSelectionCount, required this.returnCaptureSkippedCount, this.watchForPromptAcceptanceRate,
    this.returnCaptureQuickAnswerSelectionRate,
    this.returnCaptureRecordedAfterQuickAnswerRate,
  });

  final int firstPatternCorrectionCount;

  /// True when users often correct the first pattern — quality may be weak.
  final bool firstPatternQualityWeak;
  final int watchForPromptShownCount;
  final int watchForPromptAcceptedCount;
  final double? watchForPromptAcceptanceRate;
  final int returnCaptureQuickAnswerSelectedCount;
  final int returnCaptureRecordedAfterSelectionCount;
  final int returnCaptureSkippedCount;
  final double? returnCaptureQuickAnswerSelectionRate;
  final double? returnCaptureRecordedAfterQuickAnswerRate;
}