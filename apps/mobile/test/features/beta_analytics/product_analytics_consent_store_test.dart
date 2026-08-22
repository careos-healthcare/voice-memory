import 'dart:io';

import 'package:archiveme_mobile/features/beta_analytics/product_analytics_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late MobilePrefsStore prefs;
  late ProductAnalyticsConsentStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('analytics_consent_test');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    store = ProductAnalyticsConsentStore(prefs);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('ProductAnalyticsConsentStore', () {
    test('a fresh install has not granted collection', () async {
      // The whole point of the store: dormancy (missing Firebase keys) must not
      // be the only thing keeping collection off.
      expect(await store.isGrantedNow(), isFalse);

      final state = await store.current();
      expect(state.granted, isFalse);
      expect(state.isDecided, isFalse);
    });

    test('grant records an affirmative decision with a timestamp', () async {
      final state = await store.grant();

      expect(state.granted, isTrue);
      expect(state.isDecided, isTrue);
      expect(await store.isGrantedNow(), isTrue);
    });

    test('withdraw turns collection back off', () async {
      await store.grant();
      final state = await store.withdraw();

      expect(state.granted, isFalse);
      // A withdrawal is still a decision, so it must not read as "never asked".
      expect(state.isDecided, isTrue);
      expect(await store.isGrantedNow(), isFalse);
    });

    test('a decision survives a new store over the same prefs', () async {
      await store.grant();

      final reopened = ProductAnalyticsConsentStore(prefs);
      expect(await reopened.isGrantedNow(), isTrue);
    });

    test('onChanged emits every decision', () async {
      final seen = <bool>[];
      final subscription = store.onChanged.listen(
        (state) => seen.add(state.granted),
      );
      addTearDown(subscription.cancel);

      await store.grant();
      await store.withdraw();
      await Future<void>.delayed(Duration.zero);

      expect(seen, [true, false]);
    });

    group('fails closed', () {
      test('a malformed record is not permission', () async {
        await prefs.writeJsonMap(ProductAnalyticsConsentStore.prefsKey, {
          'granted': 'yes',
          'policyVersion': 'not-an-int',
        });

        expect(await store.isGrantedNow(), isFalse);
      });

      test('an absent flag is not permission', () async {
        await prefs.writeJsonMap(ProductAnalyticsConsentStore.prefsKey, {
          'decidedAt': DateTime.now().toUtc().toIso8601String(),
        });

        expect(await store.isGrantedNow(), isFalse);
      });
    });

    test('does not share storage with remote-processing consent', () async {
      // These are separate concepts — `BetaAnalyticsConsentBoundary` documents
      // that product analytics is not covered by remote-processing consent — so
      // granting one must never grant the other.
      expect(
        ProductAnalyticsConsentStore.prefsKey,
        isNot(RemoteProcessingConsentStore.prefsKey),
      );

      await RemoteProcessingConsentStore(prefs).grant();

      expect(await store.isGrantedNow(), isFalse);
    });

    test('serialises round-trip', () async {
      await store.grant();
      final raw = await prefs.readJsonMap(
        ProductAnalyticsConsentStore.prefsKey,
      );

      final restored = ProductAnalyticsConsentState.fromJson(raw!);
      expect(restored.granted, isTrue);
      expect(
        restored.policyVersion,
        ProductAnalyticsConsentStore.currentPolicyVersion,
      );
    });
  });
}
