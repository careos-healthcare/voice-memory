import 'package:archiveme_mobile/router/v1_route_registry.dart';

enum ProductionRouteCtaSurface {
  record,
  archive,
  account,
  settings,
  security,
  export,
  deletion,
  consent,
  momentDetail,
}

/// Visible CTAs on focused-beta production surfaces and their route targets.
class ProductionRouteCta {
  const ProductionRouteCta({
    required this.id,
    required this.surface,
    required this.route,
    required this.widgetKey,
  });

  final String id;
  final ProductionRouteCtaSurface surface;
  final String route;
  final String widgetKey;
}

/// Authoritative CTA list for route-link integration tests and validators.
abstract final class ProductionRouteCtaRegistry {
  ProductionRouteCtaRegistry._();

  static const fixtureMarker = 'PRODUCTION_ROUTE_LINK_FIXTURE';

  static const ctas = [
    ProductionRouteCta(
      id: 'account_export',
      surface: ProductionRouteCtaSurface.account,
      route: V1RouteRegistry.exportPath,
      widgetKey: 'account_control_export_button',
    ),
    ProductionRouteCta(
      id: 'account_privacy_policy',
      surface: ProductionRouteCtaSurface.account,
      route: V1RouteRegistry.privacyPath,
      widgetKey: 'account_control_privacy_policy_button',
    ),
    ProductionRouteCta(
      id: 'account_support',
      surface: ProductionRouteCtaSurface.account,
      route: V1RouteRegistry.supportFeedbackPath,
      widgetKey: 'account_control_support_button',
    ),
    ProductionRouteCta(
      id: 'account_privacy_trust_centre',
      surface: ProductionRouteCtaSurface.account,
      route: V1RouteRegistry.privacyTrustCentrePath,
      widgetKey: 'account_privacy_trust_centre_tile',
    ),
    ProductionRouteCta(
      id: 'account_settings',
      surface: ProductionRouteCtaSurface.account,
      route: V1RouteRegistry.settingsPath,
      widgetKey: 'account_open_settings_button',
    ),
    ProductionRouteCta(
      id: 'settings_privacy_trust_centre',
      surface: ProductionRouteCtaSurface.settings,
      route: V1RouteRegistry.privacyTrustCentrePath,
      widgetKey: 'settings_privacy_trust_centre_tile',
    ),
    ProductionRouteCta(
      id: 'settings_security',
      surface: ProductionRouteCtaSurface.settings,
      route: V1RouteRegistry.securityPath,
      widgetKey: 'settings_security_tile',
    ),
    ProductionRouteCta(
      id: 'settings_delete_account',
      surface: ProductionRouteCtaSurface.deletion,
      route: V1RouteRegistry.deleteAccountPath,
      widgetKey: 'settings_security_tile',
    ),
    ProductionRouteCta(
      id: 'security_export',
      surface: ProductionRouteCtaSurface.export,
      route: V1RouteRegistry.exportPath,
      widgetKey: 'security_export',
    ),
    ProductionRouteCta(
      id: 'security_delete_account',
      surface: ProductionRouteCtaSurface.deletion,
      route: V1RouteRegistry.deleteAccountPath,
      widgetKey: 'security_delete',
    ),
    ProductionRouteCta(
      id: 'security_sign_in',
      surface: ProductionRouteCtaSurface.account,
      route: V1RouteRegistry.accountSignInPath,
      widgetKey: 'security_sign_in',
    ),
    ProductionRouteCta(
      id: 'security_create_account',
      surface: ProductionRouteCtaSurface.account,
      route: V1RouteRegistry.accountCreatePath,
      widgetKey: 'security_create_account',
    ),
  ];
}
