import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/revenuecat_app_user_id_store.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/models/entitlement.dart';
import 'package:voicememory_mobile/storage/entitlement_cache.dart';

import 'helpers/memory_secure_storage.dart';

const _pro = PremiumEntitlements(
  tier: BillingTier.pro,
  entitlementIds: ['pro'],
  billingConnected: true,
  source: 'revenuecat',
);

void main() {
  late Directory directory;
  late DateTime now;
  late EntitlementCache cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rc_cache_policy_');
    now = DateTime.utc(2026, 7, 1, 12);
    cache = await EntitlementCache.open(
      '${directory.path}/entitlements.json',
      now: () => now,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('offline Pro remains available for less than five days', () async {
    await cache.save(_pro);
    now = now.add(const Duration(days: 4, hours: 23, minutes: 59));

    expect((await cache.load())?.isPro, isTrue);
  });

  test('offline Pro expires at exactly five days and is deleted', () async {
    await cache.save(_pro);
    now = now.add(EntitlementCache.maxOfflineProAge);

    expect(await cache.load(), isNull);
    expect(cache.file.existsSync(), isFalse);
  });

  test(
    'reading and re-saving offline Pro does not extend its deadline',
    () async {
      await cache.save(_pro);
      now = now.add(const Duration(days: 4));
      final offline = await cache.load();
      expect(offline?.isPro, isTrue);
      await cache.save(offline!);

      now = now.add(const Duration(days: 1));
      expect(await cache.load(), isNull);
    },
  );

  test('legacy and future-dated Pro cache entries fail closed', () async {
    await cache.file.writeAsString(jsonEncode(_pro.toJson()));
    expect(await cache.load(), isNull);

    await cache.save(_pro);
    now = now.subtract(const Duration(minutes: 1));
    expect(await cache.load(), isNull);
  });

  test('version-one cache envelope remains backward compatible', () async {
    await cache.file.writeAsString(
      jsonEncode({
        'version': 1,
        'cachedAt': now.toIso8601String(),
        'entitlements': {
          'tier': 'pro',
          'entitlements': ['archive_loop_pro'],
          'billingConnected': true,
          'source': 'revenuecat',
        },
      }),
    );

    final loaded = await cache.load();
    expect(loaded?.isPro, isTrue);
    expect(loaded?.verification, EntitlementVerification.cached);
  });

  test('RevenueCat cached verification uses the same strict boundary', () {
    const requestDate = '2026-07-01T12:00:00.000Z';
    expect(
      RevenueCatService.isVerificationFresh(
        requestDate,
        now: DateTime.utc(2026, 7, 6, 11, 59, 59),
      ),
      isTrue,
    );
    expect(
      RevenueCatService.isVerificationFresh(
        requestDate,
        now: DateTime.utc(2026, 7, 6, 12),
      ),
      isFalse,
    );
  });

  test('RevenueCat App User ID is a persistent UUID v4', () async {
    final secureStorage = MemorySecureStorage();
    final store = RevenueCatAppUserIdStore(secureStorage: secureStorage);

    final first = await store.getOrCreate();
    final second = await store.getOrCreate();

    expect(RevenueCatAppUserIdStore.isValidUuid(first), isTrue);
    expect(second, first);
    expect(
      await secureStorage.read(RevenueCatAppUserIdStore.storageKey),
      first,
    );
  });

  test('RevenueCat configuration always includes the custom UUID', () {
    const appUserId = 'f81d4fae-7dec-4f12-a765-00a0c91e6bf6';
    final configuration = RevenueCatService.buildConfiguration(
      'test_api_key',
      appUserId,
    );

    expect(configuration.appUserID, appUserId);
    expect(
      RevenueCatService.requiredRestoreBehavior,
      'Transfer to new App User ID',
    );
    expect(
      () => RevenueCatService.buildConfiguration('test_api_key', 'invalid'),
      throwsArgumentError,
    );
  });
}
