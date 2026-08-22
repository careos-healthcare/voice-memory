import 'package:archiveme_mobile/router/route_catalog.dart';
import 'package:flutter/material.dart';

/// Resolves legacy Changes deep links into Archive-owned routes.
abstract final class ArchiveChangesDeepLink {
  ArchiveChangesDeepLink._();

  static const unavailableQueryKey = 'changesUnavailable';

  /// Nested Archive route when eligibility passes at runtime.
  static const nestedChangesPath = '${RouteCatalog.archiveHome}/changes';

  /// Legacy top-level path retained for deep links — not a primary tab.
  static const legacyPath = RouteCatalog.changesHome;

  static bool isLegacyChangesUri(Uri uri) =>
      uri.path == legacyPath || uri.path == nestedChangesPath;

  static bool showsUnavailableNotice(Uri uri) =>
      uri.queryParameters[unavailableQueryKey] == '1';

  static String archiveWithUnavailableNotice() =>
      '${RouteCatalog.archiveHome}?$unavailableQueryKey=1';
}
