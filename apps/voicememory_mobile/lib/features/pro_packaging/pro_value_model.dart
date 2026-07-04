/// One titled bullet list in the Pro packaging surface.
class ProPackagingSection {
  const ProPackagingSection({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}

/// Display-only packaging state for Account and paywall surfaces.
class ProPackagingDisplay {
  const ProPackagingDisplay({
    required this.title,
    required this.subtitle,
    required this.free,
    required this.pro,
    required this.offeringsAvailable,
    required this.showPlanPrices,
    required this.unavailableBody,
    required this.continueCta,
    required this.purchaseCta,
    required this.restoreLabel,
  });

  final String title;
  final String subtitle;
  final ProPackagingSection free;
  final ProPackagingSection pro;
  final bool offeringsAvailable;
  final bool showPlanPrices;
  final String unavailableBody;
  final String continueCta;
  final String purchaseCta;
  final String restoreLabel;
}
