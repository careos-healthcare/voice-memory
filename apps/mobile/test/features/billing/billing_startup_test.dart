import 'dart:async';
import 'dart:io';
import '../../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/billing/store_billing_port.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/di/storage_providers.dart';
import 'package:archiveme_mobile/features/billing/application/billing_notifier.dart';
import 'package:archiveme_mobile/features/billing/application/billing_startup_result.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/entitlement_cache.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/pro_status_sqlite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeStoreBillingPort implements StoreBillingPort {
  _FakeStoreBillingPort({
    this.refreshError,
  }) : refreshResult = const PremiumEntitlements(
      tier: BillingTier.pro,
      entitlementIds: ['archive_loop_pro'],
      billingConnected: true,
      source: 'revenuecat',
    ), configured = true;

  final bool configured;
  final PremiumEntitlements refreshResult;
  final Object? refreshError;

  @override
  bool get isConfigured => configured;

  @override
  Stream<PremiumEntitlements> get entitlementStream =>
      const Stream.empty();

  @override
  Future<PremiumEntitlements> refreshEntitlements() async {
    if (refreshError != null) throw refreshError!;
    return refreshResult;
  }

  @override
  Future<PremiumEntitlements> purchasePackage(Package package) async =>
      refreshResult;

  @override
  Future<PremiumEntitlements> restorePurchases() async => refreshResult;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await AppSqliteDatabase.resetForTest();
  });

  test('initializeOnStartup uses sqlite cache when RevenueCat is offline', () async {
    final sqlite = await openTestAppSqliteDatabase();
    final proRepo = ProStatusSqliteRepository(sqlite);
    await proRepo.save(
      const PremiumEntitlements(
        tier: BillingTier.pro,
        entitlementIds: ['archive_loop_pro'],
        billingConnected: true,
        source: 'revenuecat',
      ),
      syncedFrom: 'sqlite_cache',
    );

    final cacheDir = await Directory.systemTemp.createTemp('billing_startup_');
    final entitlementCache = await EntitlementCache.open(
      '${cacheDir.path}/entitlements.json',
    );

    final container = ProviderContainer(
      overrides: [
        storeBillingPortProvider.overrideWithValue(
          _FakeStoreBillingPort(
            refreshError: Exception('offline'),
          ),
        ),
        entitlementCacheHolderProvider.overrideWithValue(
          EntitlementCacheHolder()..value = entitlementCache,
        ),
        appSqliteDatabaseHolderProvider.overrideWithValue(
          AppSqliteDatabaseHolder()..value = sqlite,
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(billingProvider.notifier)
        .initializeOnStartup();

    expect(result.source, BillingStartupSource.sqliteCache);
    expect(result.isPro, isTrue);
    expect(result.revenueCatChecked, isTrue);
    expect(result.revenueCatReachable, isFalse);
  });

  test('initializeOnStartup refreshes from RevenueCat when online', () async {
    final sqlite = await openTestAppSqliteDatabase();
    final cacheDir = await Directory.systemTemp.createTemp('billing_startup_');
    final entitlementCache = await EntitlementCache.open(
      '${cacheDir.path}/entitlements.json',
    );

    final container = ProviderContainer(
      overrides: [
        storeBillingPortProvider.overrideWithValue(_FakeStoreBillingPort()),
        entitlementCacheHolderProvider.overrideWithValue(
          EntitlementCacheHolder()..value = entitlementCache,
        ),
        appSqliteDatabaseHolderProvider.overrideWithValue(
          AppSqliteDatabaseHolder()..value = sqlite,
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(billingProvider.notifier)
        .initializeOnStartup();

    expect(result.source, BillingStartupSource.revenueCat);
    expect(result.isPro, isTrue);
    expect(result.revenueCatReachable, isTrue);

    final sqliteRecord = await ProStatusSqliteRepository(sqlite).load();
    expect(sqliteRecord?.syncedFrom, 'revenuecat');
  });
}