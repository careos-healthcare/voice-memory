import 'route_catalog.dart';

/// Retired deep links handled only by the global navigation guard.
abstract final class LegacyRouteAliases {
  static const redirects = <String, String>{
    '/memory': RouteCatalog.archiveHome,
    '/discover': RouteCatalog.archiveHome,
    '/timeline': RouteCatalog.archiveHome,
    '/search': RouteCatalog.archiveHome,
    '/discover-changes': RouteCatalog.archiveHome,
    '/archive-detail': RouteCatalog.archiveHome,
    '/discover-yourself': RouteCatalog.archiveHome,
  };
}
