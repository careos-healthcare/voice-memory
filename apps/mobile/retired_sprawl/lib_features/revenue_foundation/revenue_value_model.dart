/// Safe revenue value flags and display model — no billing or journal content.
class RevenueValueFoundation {
  const RevenueValueFoundation({
    required this.hasClearPaidReason,
    required this.longTermHistoryValue,
    required this.privateReportValue,
    required this.exportValue,
    required this.safeSharingFutureValue,
    required this.exportReportsLive,
    required this.privateReportsLive,
    required this.longTermHistoryLive,
    required this.safeSharingLive,
    required this.paidReasonHeadline,
    required this.paidReasonBody,
    required this.paidReasonEvidenceLine,
    required this.chatGptDifferentiationLine,
    required this.comparesMomentsLine,
    required this.longTermHistoryHeadline,
    required this.longTermHistoryBody,
    required this.privateReportHeadline,
    required this.privateReportBody,
    required this.exportHeadline,
    required this.exportBody,
    required this.exportLabel,
    required this.safeSharingHeadline,
    required this.safeSharingBody,
    required this.safeSharingDisclaimer,
    required this.safeSharingChoice,
    required this.safeSharingFutureNote,
    required this.positioningHeadline,
    required this.positioningSubhead,
    required this.memoryJob,
  });

  /// Clear paid reason copy is defined and articulates memory — not AI chat.
  final bool hasClearPaidReason;

  /// Long-term archive history is a live Pro value pillar.
  final bool longTermHistoryValue;

  /// Private reports are a live or partial Pro value pillar.
  final bool privateReportValue;

  /// Export is a live Pro value pillar (false when only planned).
  final bool exportValue;

  /// Future-safe sharing copy exists; feature is not sold as live.
  final bool safeSharingFutureValue;

  final bool exportReportsLive;
  final bool privateReportsLive;
  final bool longTermHistoryLive;
  final bool safeSharingLive;

  final String paidReasonHeadline;
  final String paidReasonBody;
  final String paidReasonEvidenceLine;
  final String chatGptDifferentiationLine;
  final String comparesMomentsLine;
  final String longTermHistoryHeadline;
  final String longTermHistoryBody;
  final String privateReportHeadline;
  final String privateReportBody;
  final String exportHeadline;
  final String exportBody;
  final String exportLabel;
  final String safeSharingHeadline;
  final String safeSharingBody;
  final String safeSharingDisclaimer;
  final String safeSharingChoice;
  final String safeSharingFutureNote;
  final String positioningHeadline;
  final String positioningSubhead;
  final String memoryJob;

  List<String> get allVisibleStrings => [
    positioningHeadline,
    positioningSubhead,
    memoryJob,
    paidReasonHeadline,
    paidReasonBody,
    paidReasonEvidenceLine,
    chatGptDifferentiationLine,
    comparesMomentsLine,
    longTermHistoryHeadline,
    longTermHistoryBody,
    privateReportHeadline,
    privateReportBody,
    exportHeadline,
    exportBody,
    exportLabel,
    safeSharingHeadline,
    safeSharingBody,
    safeSharingDisclaimer,
    safeSharingChoice,
    if (!safeSharingLive) safeSharingFutureNote,
  ];
}