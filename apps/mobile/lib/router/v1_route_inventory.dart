import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';

/// Authoritative V1 route inventory and classification.
///
/// Every production route must map to exactly one [V1RouteClass].
/// Quarantined routes remain registered for deep-link redirects but are not
/// allowlisted in [V1NavigationGuard].
abstract final class V1RouteInventory {
  V1RouteInventory._();

  static const primaryShell = [
    V1RouteEntry('/record', V1RouteClass.v1Core, 'Fast voice capture'),
    V1RouteEntry('/archive-belief', V1RouteClass.v1Core, 'Original archive + search'),
    V1RouteEntry('/belief-changes', V1RouteClass.v1Core, 'Cautious verified changes'),
    V1RouteEntry('/account', V1RouteClass.v1Core, 'Account and settings hub'),
  ];

  static const supporting = [
    V1RouteEntry('/onboarding', V1RouteClass.v1Supporting, 'First launch consent'),
    V1RouteEntry('/entry/:id', V1RouteClass.v1Supporting, 'Entry detail'),
    V1RouteEntry(
      '/belief-evidence',
      V1RouteClass.v1Supporting,
      'Exact supporting evidence',
    ),
    V1RouteEntry('/belief-detail', V1RouteClass.v1Supporting, 'Change detail'),
    V1RouteEntry('/quick-capture', V1RouteClass.v1Supporting, 'Fast text capture'),
    V1RouteEntry('/settings', V1RouteClass.v1Supporting, 'Settings'),
    V1RouteEntry('/security', V1RouteClass.v1Supporting, 'Security'),
    V1RouteEntry(
      '/privacy-security',
      V1RouteClass.v1Supporting,
      'Privacy & security control center',
    ),
    V1RouteEntry(
      '/caregiver-access',
      V1RouteClass.v1Supporting,
      'Caregiver and observer access',
    ),
    V1RouteEntry('/privacy', V1RouteClass.v1Supporting, 'Privacy'),
    V1RouteEntry(
      '/privacy-trust-centre',
      V1RouteClass.v1Supporting,
      'Privacy centre',
    ),
    V1RouteEntry('/terms', V1RouteClass.v1Supporting, 'Terms'),
    V1RouteEntry('/about', V1RouteClass.v1Supporting, 'About'),
    V1RouteEntry('/export', V1RouteClass.v1Supporting, 'Export'),
    V1RouteEntry('/delete-account', V1RouteClass.v1Supporting, 'Account deletion'),
    V1RouteEntry('/support-feedback', V1RouteClass.v1Supporting, 'Required support'),
    V1RouteEntry('/account/create', V1RouteClass.v1Supporting, 'Authentication'),
    V1RouteEntry('/account/sign-in', V1RouteClass.v1Supporting, 'Authentication'),
    V1RouteEntry(
      '/account/guest-data-migration',
      V1RouteClass.v1Supporting,
      'Guest migration',
    ),
  ];

  static const paid = [
    V1RouteEntry('/subscription', V1RouteClass.paidV1, 'Paywall'),
    V1RouteEntry('/pricing', V1RouteClass.paidV1, 'Plan selection'),
    V1RouteEntry('/restore-purchases', V1RouteClass.paidV1, 'Restoration'),
  ];

  /// Registered in router but blocked by V1 guard — redirect to Archive/Record.
  static const quarantineExamples = [
    V1RouteEntry('/capacity-loop', V1RouteClass.quarantine, 'Capacity lab'),
    V1RouteEntry('/beta-feedback', V1RouteClass.quarantine, 'Beta laboratory'),
    V1RouteEntry('/journal', V1RouteClass.quarantine, 'Legacy journal surface'),
    V1RouteEntry('/pattern-map', V1RouteClass.quarantine, 'Competing pattern system'),
    V1RouteEntry('/archive-packs', V1RouteClass.quarantine, 'Archive packs'),
    V1RouteEntry('/testing-archiveme', V1RouteClass.quarantine, 'Tester dashboard'),
  ];

  static int get productionRouteCountBeforeConsolidation => 105;

  /// Screen routes with builders in V1 production router (approximate).
  static int get v1ProductionBuilderRouteCount => 28;

  static int get v1QuarantineRedirectRouteCount =>
      V1RouteRegistry.quarantinedExactPaths.length +
      V1RouteRegistry.parameterizedQuarantinePaths.length;

  static int get v1AllowlistedRouteCount =>
      V1RouteRegistry.allowlistedRouteCount;
}

enum V1RouteClass { v1Core, v1Supporting, paidV1, quarantine, removeObsolete }

class V1RouteEntry {
  const V1RouteEntry(this.path, this.v1Class, this.capability);
  final String path;
  final V1RouteClass v1Class;
  final String capability;
}
