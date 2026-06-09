/// Why the paywall opened — memory limits and Pro archive features.
enum PaywallTrigger {
  keyMomentsLimit,
  patternMapFull,
  archiveTimelineFull,
  archiveMemoryFull,
  monthlyReview,
  privateExport,
  fullHistory,
}

/// Context passed to the paywall for trigger-specific copy.
class PaywallTriggerContext {
  const PaywallTriggerContext({
    required this.trigger,
    required this.sourceRoute,
    this.momentCount = 0,
    this.checkInCount = 0,
    this.weekCount = 0,
    required this.previewTitle,
    required this.previewBody,
    required this.ctaLabel,
  });

  final PaywallTrigger trigger;
  final String sourceRoute;
  final int momentCount;
  final int checkInCount;
  final int weekCount;
  final String previewTitle;
  final String previewBody;
  final String ctaLabel;

  PaywallTriggerContext copyWith({
    PaywallTrigger? trigger,
    String? sourceRoute,
    int? momentCount,
    int? checkInCount,
    int? weekCount,
    String? previewTitle,
    String? previewBody,
    String? ctaLabel,
  }) =>
      PaywallTriggerContext(
        trigger: trigger ?? this.trigger,
        sourceRoute: sourceRoute ?? this.sourceRoute,
        momentCount: momentCount ?? this.momentCount,
        checkInCount: checkInCount ?? this.checkInCount,
        weekCount: weekCount ?? this.weekCount,
        previewTitle: previewTitle ?? this.previewTitle,
        previewBody: previewBody ?? this.previewBody,
        ctaLabel: ctaLabel ?? this.ctaLabel,
      );
}
