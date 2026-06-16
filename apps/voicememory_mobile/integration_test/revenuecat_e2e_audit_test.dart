import 'dart:convert';
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
import 'package:voicememory_mobile/features/archive_synthesis/archive_synthesis_pro_gate.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import '../tool/full_visual_audit.dart';

/// RevenueCat E2E production audit — writes runtime JSON + screenshots (no code-only claims).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final logLines = <String>[];
  void log(String line) {
    logLines.add(line);
    debugPrint('RC_E2E: $line');
  }

  var surfaceConverted = false;
  Directory? outDir;

  Future<Directory> outputDir() async {
    if (outDir != null) return outDir!;
    if (Platform.isAndroid) {
      outDir = Directory('/sdcard/Download/revenuecat_e2e');
      if (!outDir!.existsSync()) outDir!.createSync(recursive: true);
      return outDir!;
    }
    outDir = Directory(
      '${(await getTemporaryDirectory()).path}/revenuecat_e2e',
    );
    if (!outDir!.existsSync()) outDir!.createSync(recursive: true);
    return outDir!;
  }

  Future<String> snap(WidgetTester tester, String name) async {
    if (!kIsWeb && Platform.isAndroid && !surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final bytes = await binding.takeScreenshot(name);
    final path = '${(await outputDir()).path}/$name.png';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> go(WidgetTester tester, String route) async {
    appRouter.go(route);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Map<String, dynamic> step({
    required int n,
    required String name,
    required bool pass,
    required String screenshot,
    required String entitlementState,
    String? notes,
  }) {
    return {
      'step': n,
      'name': name,
      'result': pass ? 'PASS' : 'FAIL',
      'screenshot': screenshot,
      'entitlement_state': entitlementState,
      if (notes != null) 'notes': notes,
    };
  }

  testWidgets('RevenueCat E2E runtime audit', (tester) async {
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
    final billing = AppServices.instance.billing;
    String entitlementLabel(PremiumEntitlements e) =>
        '${e.tier.name}; pro=${e.isPro}; ids=${e.entitlementIds.join(",")}; source=${e.source}';

    log('platform=${Platform.operatingSystem}');
    log('sdk_configured=${rc.isConfigured}');

    PremiumEntitlements ent = PremiumEntitlements.free();
    try {
      ent = await billing.loadEntitlements(forceRefresh: true);
    } catch (e) {
      log('loadEntitlements_error=$e');
    }
    log('entitlements_after_init=${entitlementLabel(ent)}');

    final steps = <Map<String, dynamic>>[];

    // 1 Initialize
    final s1Shot = await snap(tester, 'step01_sdk_init');
    final initPass = rc.isConfigured;
    log(
      initPass
          ? 'Purchases.configure succeeded'
          : 'RevenueCat: disabled — no API key at build time',
    );
    steps.add(
      step(
        n: 1,
        name: 'RevenueCat initializes successfully',
        pass: initPass,
        screenshot: s1Shot,
        entitlementState: entitlementLabel(ent),
        notes: initPass
            ? null
            : 'No REVENUECAT_ANDROID_API_KEY / REVENUECAT_IOS_API_KEY in build',
      ),
    );

    // 2 Offerings
    Offerings? offerings;
    if (rc.isConfigured) {
      try {
        offerings = await rc.fetchOfferings();
        log('offerings_current=${offerings?.current?.identifier}');
        log(
          'package_count=${offerings?.current?.availablePackages.length ?? 0}',
        );
      } catch (e) {
        log('fetchOfferings_error=$e');
      }
    }
    await go(tester, '/revenuecat-verify');
    await tester.pump(const Duration(seconds: 1));
    final s2Shot = await snap(tester, 'step02_offerings');
    final offeringsPass =
        offerings?.current != null &&
        offerings!.current!.availablePackages.isNotEmpty;
    steps.add(
      step(
        n: 2,
        name: 'Offerings load',
        pass: offeringsPass,
        screenshot: s2Shot,
        entitlementState: entitlementLabel(ent),
      ),
    );

    // 3 Monthly
    Package? monthly;
    Package? annual;
    if (offerings?.current != null) {
      for (final p in offerings!.current!.availablePackages) {
        if (p.packageType == PackageType.monthly) monthly = p;
        if (p.packageType == PackageType.annual) annual = p;
        log(
          'package type=${p.packageType.name} id=${p.storeProduct.identifier}',
        );
      }
    }
    await go(tester, '/subscription');
    final s3Shot = await snap(tester, 'step03_monthly_product');
    steps.add(
      step(
        n: 3,
        name: 'Monthly product loads',
        pass: monthly != null,
        screenshot: s3Shot,
        entitlementState: entitlementLabel(ent),
        notes: monthly?.storeProduct.identifier,
      ),
    );

    // 4 Annual
    final s4Shot = await snap(tester, 'step04_annual_product');
    steps.add(
      step(
        n: 4,
        name: 'Annual product loads',
        pass: annual != null,
        screenshot: s4Shot,
        entitlementState: entitlementLabel(ent),
        notes: annual?.storeProduct.identifier,
      ),
    );

    // 5–12 — require sandbox purchase; not executed without configured store + tester action
    final blockedNote =
        'Not executed: SDK/store not configured for sandbox IAP in this automated run';
    for (final spec in [
      (5, 'step05_purchase', 'Purchase flow completes'),
      (6, 'step06_rc_dashboard', 'RevenueCat dashboard shows transaction'),
      (7, 'step07_pro_entitlement', 'Entitlement pro becomes active'),
      (8, 'step08_archive_unlock', 'Archive Intelligence unlocks'),
      (9, 'step09_restart', 'App restart preserves entitlement'),
      (10, 'step10_restore', 'Restore purchases works'),
      (11, 'step11_fresh_install', 'Fresh install restores entitlement'),
      (12, 'step12_offline_cache', 'Offline entitlement cache works'),
    ]) {
      final shot = await snap(tester, spec.$2);
      String? notes = blockedNote;
      var pass = false;
      if (spec.$1 == 12) {
        final cached = await AppServices.instance.entitlementCache.load();
        log(
          'offline_cache=${cached != null ? entitlementLabel(cached) : "empty"}',
        );
        notes =
            'Cache read only; no Pro purchase to verify offline Pro persistence. cached=${cached?.isPro ?? false}';
      }
      if (spec.$1 == 8) {
        final canAccess = ArchiveSynthesisProGate.canAccessArchiveIntelligence(
          ent,
        );
        log('archive_intelligence_gate=$canAccess');
        notes = 'Pro gate from current entitlements: $canAccess';
      }
      steps.add(
        step(
          n: spec.$1,
          name: spec.$3,
          pass: pass,
          screenshot: shot,
          entitlementState: entitlementLabel(ent),
          notes: notes,
        ),
      );
    }

    final deviceInfo = Platform.isAndroid
        ? 'sdk_gphone16k_arm64 (emulator-5554)'
        : Platform.isIOS
        ? 'ios_device'
        : 'unknown';

    final payload = {
      'audit': 'revenuecat_e2e_production',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'device': deviceInfo,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'sandbox_account': 'not_used',
      'sdk_initialized': rc.isConfigured,
      'overall_pass': steps.every((s) => s['result'] == 'PASS'),
      'pass_count': steps.where((s) => s['result'] == 'PASS').length,
      'fail_count': steps.where((s) => s['result'] == 'FAIL').length,
      'revenuecat_logs': logLines,
      'steps': steps,
      'adb_pull_dir': (await outputDir()).path,
    };

    final jsonPath = '${(await outputDir()).path}/revenuecat_e2e_runtime.json';
    await File(jsonPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    log('EVIDENCE_JSON=$jsonPath');

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
