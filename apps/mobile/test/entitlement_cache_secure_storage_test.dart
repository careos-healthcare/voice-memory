import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:archiveme_mobile/storage/in_memory_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntitlementCache secure storage', () {
    test('persists and loads from secure storage', () async {
      final secure = InMemorySecureStorageService();
      final cache = await EntitlementCache.open(
        '/tmp/vm_entitlement_cache_test.json',
        secureStorage: secure,
      );
      const entitlements = PremiumEntitlements(
        tier: BillingTier.pro,
        entitlementIds: ['pro'],
        billingConnected: true,
        source: 'test_secure_cache',
      );

      await cache.save(entitlements);
      final loaded = await cache.load();

      expect(loaded?.tier, BillingTier.pro);
      expect(loaded?.source, 'test_secure_cache');
      expect(await secure.read('entitlements_v1'), isNotNull);
    });

    test('migrates legacy plain file into secure storage', () async {
      final secure = InMemorySecureStorageService();
      final path = '/tmp/vm_entitlement_cache_migrate_test.json';
      final legacy = await EntitlementCache.open(path);
      const entitlements = PremiumEntitlements(
        tier: BillingTier.pro,
        entitlementIds: ['pro'],
        billingConnected: true,
        source: 'legacy_file',
      );
      await legacy.save(entitlements);

      final migrated = await EntitlementCache.open(
        path,
        secureStorage: secure,
      );
      final loaded = await migrated.load();

      expect(loaded?.source, 'legacy_file');
      expect(await secure.read('entitlements_v1'), isNotNull);
    });
  });
}