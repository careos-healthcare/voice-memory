import 'dart:io';

import 'package:archiveme_mobile/features/beta_analytics/product_analytics_consent_store.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The invariant this file protects: `ProductAnalytics` used to call
/// `setAnalyticsCollectionEnabled(true)` unconditionally from
/// `AppServices.initialize()`, and the only thing keeping that harmless was
/// that no committed build script supplies Firebase dart-defines. Consent is
/// now the gate, and the default is off.
///
/// Firebase is never initialized under `flutter test`, so `initialize()` returns
/// before it reaches a provider. These tests therefore assert the gate state
/// this facade keeps for itself, which is what `track` checks before sending.
void main() {
  late Directory tempDir;
  late ProductAnalyticsConsentStore store;

  setUp(() async {
    ProductAnalytics.resetForTest();
    tempDir = await Directory.systemTemp.createTemp('analytics_gate_test');
    final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    store = ProductAnalyticsConsentStore(prefs);
  });

  tearDown(() async {
    ProductAnalytics.resetForTest();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('ProductAnalytics consent gate', () {
    test('starts closed before anything initializes', () {
      expect(ProductAnalytics.consentGranted, isFalse);
    });

    test('stays closed on a fresh install', () async {
      await ProductAnalytics.initialize(consentStore: store);

      expect(await store.isGrantedNow(), isFalse);
      expect(ProductAnalytics.consentGranted, isFalse);
    });

    test('stays closed when no store is supplied', () async {
      // The fallback must resolve to "no consent", never to "assume yes".
      await ProductAnalytics.initialize();

      expect(ProductAnalytics.consentGranted, isFalse);
    });

    test('a withdrawal closes the gate again', () async {
      await ProductAnalytics.applyConsent(granted: true);
      expect(ProductAnalytics.consentGranted, isTrue);

      await ProductAnalytics.applyConsent(granted: false);
      expect(ProductAnalytics.consentGranted, isFalse);
    });

    test('only an affirmative decision opens it', () async {
      await ProductAnalytics.applyConsent(
        granted: await store.isGrantedNow(),
      );
      expect(ProductAnalytics.consentGranted, isFalse);

      await store.grant();
      await ProductAnalytics.applyConsent(
        granted: await store.isGrantedNow(),
      );
      expect(ProductAnalytics.consentGranted, isTrue);
    });

    test('resetForTest closes the gate', () async {
      await ProductAnalytics.applyConsent(granted: true);
      ProductAnalytics.resetForTest();

      expect(ProductAnalytics.consentGranted, isFalse);
    });

    test('tracking an event without consent does not throw', () async {
      // No provider and no consent: the call must be a silent no-op rather
      // than an error path that tempts a caller to bypass the gate.
      await ProductAnalytics.track('entry_saved', parameters: {'stage': 'x'});

      expect(ProductAnalytics.consentGranted, isFalse);
    });
  });
}
