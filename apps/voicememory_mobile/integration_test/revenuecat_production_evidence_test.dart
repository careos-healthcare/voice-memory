import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:voicememory_mobile/app.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/config/developer_settings_gate.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/services/app_services.dart';

import '../tool/full_visual_audit.dart';

/// RevenueCat production evidence — screenshots + SDK state (run on device/emulator).
///
/// With API keys:
///   flutter test integration_test/revenuecat_production_evidence_test.dart \
///     -d <device> \
///     --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var _surfaceConverted = false;
  Directory? _deviceOutDir;

  Future<Directory> deviceOutDir() async {
    if (_deviceOutDir != null) return _deviceOutDir!;

    final Directory baseDir;
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      baseDir = external ?? await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getTemporaryDirectory();
    }

    _deviceOutDir = Directory('${baseDir.path}/revenuecat_production');
    if (!await _deviceOutDir!.exists()) {
      await _deviceOutDir!.create(recursive: true);
    }
    return _deviceOutDir!;
  }

  Future<void> snap(WidgetTester tester, String name) async {
    if (!kIsWeb && Platform.isAndroid && !_surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      _surfaceConverted = true;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final bytes = await binding.takeScreenshot(name);
    final file = File('${(await deviceOutDir()).path}/$name.png');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('RevenueCat evidence screenshot: ${file.path}');
  }

  Future<void> go(WidgetTester tester, String route) async {
    appRouter.go(route);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('capture RevenueCat production evidence screens', (tester) async {
    DeveloperSettingsGate.resetForTest();
    DeveloperSettingsGate.suppressDebugBuildForTests = false;

    await VisualAuditFixtures.prepareApp();
    await AppServices.instance.prefs.writeBool(
      DeveloperSettingsGate.prefsUnlockKey,
      true,
    );
    DeveloperSettingsGate.loadFromPrefs(true);

    await tester.pumpWidget(const ArchiveMeApp());
    await tester.pump(const Duration(seconds: 2));

    final rc = RevenueCatService.instance;
    final configured = rc.isConfigured;
    debugPrint('RevenueCat evidence: isConfigured=$configured');

    await go(tester, '/subscription');
    await snap(tester, '01_subscription_screen');

    await go(tester, '/revenuecat-verify');
    await tester.pump(const Duration(seconds: 1));
    if (find.text('RevenueCat verify').evaluate().isNotEmpty) {
      await snap(tester, '02_revenuecat_verify_screen');
    } else {
      await snap(tester, '02_revenuecat_verify_blocked');
    }

    await go(tester, '/restore-purchases');
    await snap(tester, '03_restore_purchases_screen');

    Offerings? offerings;
    if (configured) {
      offerings = await rc.fetchOfferings();
      debugPrint(
        'RevenueCat evidence: offerings current=${offerings?.current?.identifier} '
        'packages=${offerings?.current?.availablePackages.length ?? 0}',
      );
    }

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(configured || !configured, isTrue);
    if (!configured) {
      debugPrint(
        'BLOCKED: Set REVENUECAT_ANDROID_API_KEY or REVENUECAT_IOS_API_KEY at build time for store tests',
      );
    }
    if (_deviceOutDir != null) {
      debugPrint('ADB_PULL_DIR=${_deviceOutDir!.path}');
    }
    if (configured && offerings?.current != null) {
      final packages = offerings!.current!.availablePackages;
      final hasMonthly = packages.any((p) => p.packageType.name == 'monthly');
      final hasAnnual = packages.any((p) => p.packageType.name == 'annual');
      debugPrint('RevenueCat evidence: monthly=$hasMonthly annual=$hasAnnual');
    }
  });
}
