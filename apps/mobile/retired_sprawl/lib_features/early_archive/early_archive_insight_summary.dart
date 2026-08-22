/// Short, evidence-grounded insight lines for the early archive loop.
class EarlyArchiveInsightSummary {
  const EarlyArchiveInsightSummary({
    this.repeatSummary,
    this.twoEntryRepeatSummary,
    this.triggerSummary,
    this.softeningSummary,
    this.helpfulActionSummary,
    this.timelineSubtitle,
    this.beliefEvidenceSummary,
  });

  final String? repeatSummary;
  final String? twoEntryRepeatSummary;
  final String? triggerSummary;
  final String? softeningSummary;
  final String? helpfulActionSummary;
  final String? timelineSubtitle;
  final String? beliefEvidenceSummary;

  static const empty = EarlyArchiveInsightSummary();
}