/// Where the capacity return trigger may appear — counts only.
enum CapacityReturnTriggerSurface {
  completion,
  archiveHome,
  recordLine,
  betaMissionHint,
}

/// Engine input — no journal text.
class CapacityReturnTriggerInput {
  const CapacityReturnTriggerInput({
    required this.sampleMode,
    required this.screenshotMode,
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    this.surface = CapacityReturnTriggerSurface.completion,
  });

  final bool sampleMode;
  final bool screenshotMode;
  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final CapacityReturnTriggerSurface surface;
}

/// Card / line result — fixed copy only.
class CapacityReturnTriggerResult {
  const CapacityReturnTriggerResult({
    required this.showCard,
    required this.title,
    required this.body,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.primaryDismisses,
    required this.secondaryCtaLabel,
    required this.secondaryRoute,
    required this.showSecondary,
    required this.recordProgressLine,
    required this.betaMissionHint,
    required this.capacityMomentCount,
    required this.activationTarget,
  });

  static const hidden = CapacityReturnTriggerResult(
    showCard: false,
    title: '',
    body: '',
    primaryCtaLabel: '',
    primaryRoute: '',
    primaryDismisses: false,
    secondaryCtaLabel: '',
    secondaryRoute: '',
    showSecondary: false,
    recordProgressLine: '',
    betaMissionHint: '',
    capacityMomentCount: 0,
    activationTarget: 0,
  );

  final bool showCard;
  final String title;
  final String body;
  final String primaryCtaLabel;
  final String primaryRoute;
  final bool primaryDismisses;
  final String secondaryCtaLabel;
  final String secondaryRoute;
  final bool showSecondary;
  final String recordProgressLine;
  final String betaMissionHint;
  final int capacityMomentCount;
  final int activationTarget;
}