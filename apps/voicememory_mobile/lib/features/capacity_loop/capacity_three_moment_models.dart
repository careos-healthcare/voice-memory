/// Engine input for capacity 3-moment activation — counts only.
class CapacityThreeMomentInput {
  const CapacityThreeMomentInput({
    required this.sampleMode,
    required this.capacityWedgeActive,
    required this.capacityEvidenceCount,
    required this.capacityMomentCount,
  });

  final bool sampleMode;
  final bool capacityWedgeActive;
  final int capacityEvidenceCount;
  final int capacityMomentCount;
}

/// Card / record / loop result — no journal text.
class CapacityThreeMomentResult {
  const CapacityThreeMomentResult({
    required this.hasCard,
    required this.showOnArchiveHome,
    required this.showOnRecordProgress,
    required this.showOnCapacityLoop,
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.emptyBody,
    required this.primaryCtaLabel,
    required this.primaryRoute,
    required this.capacityMomentCount,
    required this.activationTarget,
  });

  static const hidden = CapacityThreeMomentResult(
    hasCard: false,
    showOnArchiveHome: false,
    showOnRecordProgress: false,
    showOnCapacityLoop: false,
    title: '',
    subtitle: '',
    progressLabel: '',
    emptyBody: '',
    primaryCtaLabel: '',
    primaryRoute: '',
    capacityMomentCount: 0,
    activationTarget: 0,
  );

  final bool hasCard;
  final bool showOnArchiveHome;
  final bool showOnRecordProgress;
  final bool showOnCapacityLoop;
  final String title;
  final String subtitle;
  final String progressLabel;
  final String emptyBody;
  final String primaryCtaLabel;
  final String primaryRoute;
  final int capacityMomentCount;
  final int activationTarget;
}
