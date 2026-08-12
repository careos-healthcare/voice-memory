import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_navigation_guard.dart';
import 'package:archiveme_mobile/router/production_route_cta_registry.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';

/// Validates that active UI CTAs resolve to allowlisted production routes.
abstract final class ProductionRouteLinkGate {
  ProductionRouteLinkGate._();

  static const scanRoots = [
    'lib/widgets/account',
    'lib/widgets/security',
    'lib/screens/account_screen.dart',
    'lib/screens/settings_screen.dart',
    'lib/screens/security_settings_screen.dart',
    'lib/screens/export_screen.dart',
    'lib/screens/delete_account_screen.dart',
    'lib/screens/onboarding_screen.dart',
    'lib/screens/archive_belief_screen.dart',
    'lib/screens/entry_detail_screen.dart',
    'lib/screens/about_screen.dart',
    'lib/screens/privacy_screen.dart',
  ];

  static const approvedFiles = {
    'production_route_link_gate.dart',
    'production_route_cta_registry.dart',
    'v1_route_registry.dart',
    'v1_quarantine_redirects.dart',
  };

  static List<String> validateCtaRegistry() {
    final failures = <String>[];
    for (final cta in ProductionRouteCtaRegistry.ctas) {
      if (V1RouteRegistry.allQuarantinedPaths.contains(cta.route)) {
        failures.add('CTA ${cta.id} targets quarantined route ${cta.route}');
      }
      if (!V1NavigationGuard.isAllowed(cta.route) &&
          !_matchesAllowlistedPrefix(cta.route)) {
        failures.add('CTA ${cta.id} targets unregistered route ${cta.route}');
      }
    }
    return failures;
  }

  static List<String> scanSource({
    required String path,
    required List<String> lines,
    String marker = ProductionRouteCtaRegistry.fixtureMarker,
  }) {
    final failures = <String>[];
    var inFixture = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed == '// $marker' || trimmed == marker) {
        inFixture = !inFixture;
        continue;
      }
      if (inFixture) continue;
      if (trimmed.startsWith('//')) continue;

      for (final quarantined in V1RouteRegistry.quarantinedExactPaths) {
        if (_lineTargetsRoute(line, quarantined) &&
            !_hasReleaseVisibilityGuard(lines, i)) {
          failures.add(
            '$path:${i + 1}: active CTA targets quarantined route "$quarantined"',
          );
        }
      }
    }
    return failures;
  }

  static bool _hasReleaseVisibilityGuard(List<String> lines, int index) {
    final start = index - 30 < 0 ? 0 : index - 30;
    final window = lines.sublist(start, index + 1).join('\n');
    return window.contains('isNavRouteVisible(') ||
        window.contains('ArchiveBetaMissionGate.isEnabled') ||
        window.contains('DeveloperSettingsGate.canShowDeveloperSettings') ||
        window.contains('V1FeatureFlags.enableCustomReports') ||
        window.contains('V1FeatureFlags.enableActionItems') ||
        window.contains('ProductionNavigation.isNavRouteVisible(');
  }

  static List<String> validateActiveProductionGraph(String root) {
    final failures = <String>[...validateCtaRegistry()];

    for (final scanRoot in scanRoots) {
      final fullPath = '$root/$scanRoot';
      final file = File(fullPath);
      if (file.existsSync() && fullPath.endsWith('.dart')) {
        _scanFile(fullPath, failures);
        continue;
      }
      final dir = Directory(fullPath);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        _scanFile(entity.path, failures);
      }
    }

    return failures;
  }

  static void _scanFile(String path, List<String> failures) {
    if (approvedFiles.any((name) => path.endsWith(name))) return;
    failures.addAll(
      scanSource(path: path, lines: File(path).readAsLinesSync()),
    );
  }

  static bool _matchesAllowlistedPrefix(String route) {
    for (final prefix in V1RouteRegistry.prefixPaths) {
      if (route.startsWith(prefix)) return true;
    }
    return false;
  }

  static bool _lineTargetsRoute(String line, String route) {
    if (!line.contains('push(') && !line.contains('.go(')) return false;
    return line.contains("'$route'") || line.contains('"$route"');
  }
}
