enum PricingValueFramingFeedbackType {
  yes,
  maybe,
  no,
}

extension PricingValueFramingFeedbackTypeAnalytics
    on PricingValueFramingFeedbackType {
  String get analyticsValue => switch (this) {
        PricingValueFramingFeedbackType.yes => 'yes',
        PricingValueFramingFeedbackType.maybe => 'maybe',
        PricingValueFramingFeedbackType.no => 'no',
      };
}

class PricingValueFramingResult {
  const PricingValueFramingResult({
    required this.shouldShow,
    required this.title,
    required this.body,
    required this.valueExplanation,
    required this.bullets,
    required this.reassurance,
    required this.primaryCta,
    required this.secondaryCta,
    required this.feedbackPrompt,
    required this.source,
    required this.entryCount,
    required this.hasUsefulProof,
    required this.activeRepairMode,
  });

  static const hidden = PricingValueFramingResult(
    shouldShow: false,
    title: '',
    body: '',
    valueExplanation: '',
    bullets: [],
    reassurance: '',
    primaryCta: '',
    secondaryCta: '',
    feedbackPrompt: '',
    source: '',
    entryCount: 0,
    hasUsefulProof: false,
    activeRepairMode: '',
  );

  final bool shouldShow;
  final String title;
  final String body;
  final String valueExplanation;
  final List<String> bullets;
  final String reassurance;
  final String primaryCta;
  final String secondaryCta;
  final String feedbackPrompt;
  final String source;
  final int entryCount;
  final bool hasUsefulProof;
  final String activeRepairMode;
}
