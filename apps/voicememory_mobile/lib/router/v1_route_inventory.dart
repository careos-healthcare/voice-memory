/// Authoritative V1 route inventory and classification.
///
/// Every production route must map to exactly one [V1RouteClass].
/// Quarantined routes remain registered for deep-link redirects but are not
/// allowlisted in [V1NavigationGuard].
abstract final class V1RouteInventory {
  V1RouteInventory._();

  static const primaryShell = [
    _Route('/record', V1RouteClass.v1Core, 'Fast voice capture'),
    _Route('/archive-belief', V1RouteClass.v1Core, 'Original archive + search'),
    _Route('/belief-changes', V1RouteClass.v1Core, 'Cautious verified changes'),
    _Route('/account', V1RouteClass.v1Core, 'Account and settings hub'),
  ];

  static const supporting = [
    _Route('/onboarding', V1RouteClass.v1Supporting, 'First launch consent'),
    _Route('/entry/:id', V1RouteClass.v1Supporting, 'Entry detail'),
    _Route(
      '/belief-evidence',
      V1RouteClass.v1Supporting,
      'Exact supporting evidence',
    ),
    _Route('/belief-detail', V1RouteClass.v1Supporting, 'Change detail'),
    _Route('/quick-capture', V1RouteClass.v1Supporting, 'Fast text capture'),
    _Route('/settings', V1RouteClass.v1Supporting, 'Settings'),
    _Route('/security', V1RouteClass.v1Supporting, 'Security'),
    _Route('/privacy', V1RouteClass.v1Supporting, 'Privacy'),
    _Route(
      '/privacy-trust-centre',
      V1RouteClass.v1Supporting,
      'Privacy centre',
    ),
    _Route('/terms', V1RouteClass.v1Supporting, 'Terms'),
    _Route('/about', V1RouteClass.v1Supporting, 'About'),
    _Route('/export', V1RouteClass.v1Supporting, 'Export'),
    _Route('/delete-account', V1RouteClass.v1Supporting, 'Account deletion'),
    _Route('/support-feedback', V1RouteClass.v1Supporting, 'Required support'),
    _Route('/account/create', V1RouteClass.v1Supporting, 'Authentication'),
    _Route('/account/sign-in', V1RouteClass.v1Supporting, 'Authentication'),
    _Route(
      '/account/guest-data-migration',
      V1RouteClass.v1Supporting,
      'Guest migration',
    ),
  ];

  static const paid = [
    _Route('/subscription', V1RouteClass.paidV1, 'Paywall'),
    _Route('/pricing', V1RouteClass.paidV1, 'Plan selection'),
    _Route('/restore-purchases', V1RouteClass.paidV1, 'Restoration'),
  ];

  /// Registered in router but blocked by V1 guard — redirect to Archive/Record.
  static const quarantineExamples = [
    _Route('/capacity-loop', V1RouteClass.quarantine, 'Capacity lab'),
    _Route('/beta-feedback', V1RouteClass.quarantine, 'Beta laboratory'),
    _Route('/journal', V1RouteClass.quarantine, 'Legacy journal surface'),
    _Route('/pattern-map', V1RouteClass.quarantine, 'Competing pattern system'),
    _Route('/archive-packs', V1RouteClass.quarantine, 'Archive packs'),
    _Route('/testing-archiveme', V1RouteClass.quarantine, 'Tester dashboard'),
  ];

  static int get productionRouteCountBeforeConsolidation => 105;

  /// Screen routes with builders in V1 production router (approximate).
  static int get v1ProductionBuilderRouteCount => 28;

  static int get v1QuarantineRedirectRouteCount =>
      V1QuarantineRedirectRouteCount.exact +
      V1QuarantineRedirectRouteCount.parameterized;

  static int get v1AllowlistedRouteCount =>
      primaryShell.length + supporting.length + paid.length;
}

/// Mirrors [V1QuarantineRedirects] for inventory reporting without importing
/// go_router in the inventory module.
abstract final class V1QuarantineRedirectRouteCount {
  static const exact = 69;
  static const parameterized = 4;
}

enum V1RouteClass { v1Core, v1Supporting, paidV1, quarantine, removeObsolete }

class _Route {
  const _Route(this.path, this.v1Class, this.capability);
  final String path;
  final V1RouteClass v1Class;
  final String capability;
}
