import 'dart:io';

import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/core/config/v1_production_allowlist.dart';
import 'package:archiveme_mobile/router/production_route_link_gate.dart';

/// Ensures consumer production surfaces do not import billing modules while frozen.
abstract final class ProductionBillingImportGate {
  ProductionBillingImportGate._();

  static const billingImportPatterns = [
    "import 'package:archiveme_mobile/billing/",
    'import "package:archiveme_mobile/billing/',
    "import 'package:purchases_flutter/",
    "import 'package:purchases_ui_flutter/",
  ];

  static const billingRoutePatterns = [
    "'/subscription'",
    "'/pricing'",
    "'/restore-purchases'",
    "'/pro-preview'",
    'ConsumerUiCopy.freeKeepsSevenKeyMoments',
    'ConsumerUiCopy.unlockFullMemoryCta',
    'ConsumerUiCopy.paywallHeadline',
  ];

  static const exemptFileNames = {
    'production_billing_import_gate.dart',
    'production_route_link_gate.dart',
  };

  static List<String> validateConsumerProductionGraph(String root) {
    if (V1BillingCapability.isProductionReachable) return const [];

    final failures = <String>[];
    final router = File('$root/lib/router/app_router.dart');
    if (router.existsSync()) {
      failures.addAll(_scanFile(router.path, router.readAsStringSync()));
    }

    for (final scanRoot in ProductionRouteLinkGate.scanRoots) {
      final fullPath = '$root/$scanRoot';
      final file = File(fullPath);
      if (file.existsSync() && fullPath.endsWith('.dart')) {
        failures.addAll(_scanFile(fullPath, file.readAsStringSync()));
        continue;
      }
      final dir = Directory(fullPath);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        failures.addAll(_scanFile(entity.path, entity.readAsStringSync()));
      }
    }

    for (final screen in V1ProductionAllowlist.productionRouterScreens) {
      final path = '$root/lib/screens/${_screenPath(screen)}';
      final file = File(path);
      if (!file.existsSync()) continue;
      failures.addAll(_scanFile(path, file.readAsStringSync()));
    }

    return failures;
  }

  static List<String> _scanFile(String path, String content) {
    final name = path.split('/').last;
    if (exemptFileNames.contains(name)) return const [];

    final failures = <String>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final pattern in billingImportPatterns) {
        if (line.contains(pattern)) {
          failures.add('$path:${i + 1}: billing import while capability disabled');
        }
      }
      for (final pattern in billingRoutePatterns) {
        if (line.contains(pattern) && !_hasVisibilityGuard(lines, i)) {
          failures.add(
            '$path:${i + 1}: billing route/copy while capability disabled',
          );
        }
      }
    }
    return failures;
  }

  static bool _hasVisibilityGuard(List<String> lines, int index) {
    final start = index - 30 < 0 ? 0 : index - 30;
    final window = lines.sublist(start, index + 1).join('\n');
    return window.contains('ArchiveBetaMissionGate.isEnabled') ||
        window.contains('DeveloperSettingsGate.canShowDeveloperSettings') ||
        window.contains('V1BillingCapability.isProductionReachable');
  }

  static String _screenPath(String screen) {
    final snake = screen
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        )
        .replaceFirst('_', '');
    if (snake.endsWith('_screen')) {
      return '$snake.dart';
    }
    return '${snake}_screen.dart';
  }
}
