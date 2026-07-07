enum BetaTesterReportSectionId {
  whatReturned,
  whatChanged,
  whatFaded,
  whatYouCorrected,
  stillUnsure,
}

extension BetaTesterReportSectionIdStorage on BetaTesterReportSectionId {
  String get analyticsValue => switch (this) {
        BetaTesterReportSectionId.whatReturned => 'what_returned',
        BetaTesterReportSectionId.whatChanged => 'what_changed',
        BetaTesterReportSectionId.whatFaded => 'what_faded',
        BetaTesterReportSectionId.whatYouCorrected => 'what_you_corrected',
        BetaTesterReportSectionId.stillUnsure => 'still_unsure',
      };
}

class BetaTesterReportSection {
  const BetaTesterReportSection({
    required this.id,
    required this.heading,
    required this.body,
  });

  final BetaTesterReportSectionId id;
  final String heading;
  final String body;
}

class BetaTesterReportResult {
  const BetaTesterReportResult({
    required this.shouldShow,
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.footer,
    required this.betaFeedbackLine,
    required this.entryCount,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.hasCorrection,
    required this.hasFadingSignal,
    required this.hasSofteningSignal,
    required this.sectionCount,
  });

  final bool shouldShow;
  final String title;
  final String subtitle;
  final List<BetaTesterReportSection> sections;
  final String footer;
  final String betaFeedbackLine;
  final int entryCount;
  final String source;
  final bool hasConfirmedRepeat;
  final bool hasCorrection;
  final bool hasFadingSignal;
  final bool hasSofteningSignal;
  final int sectionCount;
}
