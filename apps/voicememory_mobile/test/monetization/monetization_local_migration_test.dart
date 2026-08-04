import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/monetization/data/monetization_local_migration.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/monetization/domain/generated/monetization_policy.g.dart';
import 'package:voicememory_mobile/features/monetization/domain/product_value_delivery_ledger.dart';
import 'package:voicememory_mobile/storage/entitlement_cache.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/subscriptions/data/entitlement_cache_subscription_data_source.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

SubscriptionState _subscription({
  SubscriptionTier tier = SubscriptionTier.free,
  SubscriptionVerification verification = SubscriptionVerification.verified,
  List<String> entitlementIds = const [],
  String? productIdentifier,
}) => SubscriptionState(
  tier: tier,
  entitlementIds: entitlementIds,
  billingConnected: true,
  origin: SubscriptionStateOrigin.store,
  verification: verification,
  productIdentifier: productIdentifier,
);

void main() {
  late Directory directory;
  late MobilePrefsStore prefs;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'monetization_migration_test_',
    );
    prefs = await MobilePrefsStore.open('${directory.path}/prefs.json');
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'migration is idempotent and only adds generated output evidence',
    () async {
      final migration = MonetizationLocalMigration(prefs);
      final first = await migration.run(
        subscription: _subscription(),
        discoveredGeneratedOutputs: const {
          CapabilityId.ongoingComparisons,
          CapabilityId.openOriginalEntry,
        },
        deliveredProof: const ProductValueDeliveryLedger.empty(),
      );
      final second = await migration.run(
        subscription: _subscription(),
        discoveredGeneratedOutputs: const {CapabilityId.deepArchiveSynthesis},
        deliveredProof: const ProductValueDeliveryLedger.empty(),
      );
      final third = await migration.run(
        subscription: _subscription(),
        deliveredProof: const ProductValueDeliveryLedger.empty(),
      );

      expect(first.legacyGrandfathered, isFalse);
      expect(first.productValue.generatedCapabilities, {
        CapabilityId.ongoingComparisons,
      });
      expect(second.productValue.generatedCapabilities, {
        CapabilityId.ongoingComparisons,
        CapabilityId.deepArchiveSynthesis,
      });
      expect(
        third.productValue.generatedCapabilities,
        second.productValue.generatedCapabilities,
      );
    },
  );

  test(
    'free proof is claimed from the delivery ledger, never discovery',
    () async {
      final migration = MonetizationLocalMigration(prefs);

      // Legacy discovery cannot mint free proof any more; only a real delivery
      // can, so an archive full of moments that produced nothing still has both
      // free promises open.
      final discoveredOnly = await migration.run(
        subscription: _subscription(),
        discoveredGeneratedOutputs: const {
          CapabilityId.firstEvidenceObservation,
          CapabilityId.firstEarlyComparison,
        },
        deliveredProof: const ProductValueDeliveryLedger.empty(),
      );
      expect(discoveredOnly.productValue.generatedCapabilities, isEmpty);

      final afterDelivery = await migration.run(
        subscription: _subscription(),
        deliveredProof: const ProductValueDeliveryLedger(
          policyVersion: MonetizationPolicy.policyVersion,
          firstValidObservationArtifactId: 'observation-1',
        ),
      );
      expect(afterDelivery.productValue.generatedCapabilities, {
        CapabilityId.firstEvidenceObservation,
      });
    },
  );

  test(
    'verified legacy lifetime is grandfathered and never downgraded',
    () async {
      final migration = MonetizationLocalMigration(prefs);
      final lifetime = await migration.run(
        subscription: _subscription(
          tier: SubscriptionTier.pro,
          entitlementIds: const ['archive_loop_pro'],
          productIdentifier: 'archive_loop_pro_lifetime',
        ),
      );
      final laterOrdinaryState = await migration.run(
        subscription: _subscription(),
      );

      expect(lifetime.legacyGrandfathered, isTrue);
      expect(laterOrdinaryState.legacyGrandfathered, isTrue);
    },
  );

  test('ordinary and unverified users are never granted lifetime', () async {
    final ordinary = await MonetizationLocalMigration(
      prefs,
    ).run(subscription: _subscription(productIdentifier: 'lifetime'));
    expect(ordinary.legacyGrandfathered, isFalse);

    final otherPrefs = await MobilePrefsStore.open(
      '${directory.path}/other_prefs.json',
    );
    final unverified = await MonetizationLocalMigration(otherPrefs).run(
      subscription: _subscription(
        tier: SubscriptionTier.pro,
        verification: SubscriptionVerification.cached,
        entitlementIds: const ['archive_loop_pro'],
        productIdentifier: 'archive_loop_pro_lifetime',
      ),
    );
    expect(unverified.legacyGrandfathered, isFalse);
  });

  test('subscription cache writes invoke the local migration', () async {
    final cache = await EntitlementCache.open(
      '${directory.path}/entitlements.json',
    );
    final source = EntitlementCacheSubscriptionDataSource(
      cache,
      MonetizationLocalMigration(prefs),
    );

    await source.save(
      _subscription(
        tier: SubscriptionTier.pro,
        entitlementIds: const ['archive_loop_pro'],
        productIdentifier: 'archive_loop_pro_lifetime',
      ),
    );

    final stored = await prefs.readMap(MonetizationLocalMigration.storageKey);
    expect(stored?['legacyGrandfathered'], isTrue);
  });
}
