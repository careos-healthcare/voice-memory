import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/pro_status_sqlite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('save and load pro snapshot round-trip', () async {
    final db = await AppSqliteDatabase.open(filePath: ':memory:');
    final repository = ProStatusSqliteRepository(db);

    const entitlements = PremiumEntitlements(
      tier: BillingTier.pro,
      entitlementIds: ['archive_loop_pro'],
      billingConnected: true,
      source: 'revenuecat',
    );

    await repository.save(entitlements, syncedFrom: 'revenuecat');
    final loaded = await repository.load();

    expect(loaded, isNotNull);
    expect(loaded!.entitlements.isPro, isTrue);
    expect(loaded.syncedFrom, 'revenuecat');
    expect(loaded.entitlements.entitlementIds, ['archive_loop_pro']);
  });

  test('clear removes persisted snapshot', () async {
    final db = await AppSqliteDatabase.open(filePath: ':memory:');
    final repository = ProStatusSqliteRepository(db);

    await repository.save(
      PremiumEntitlements.free(),
      syncedFrom: 'json_cache',
    );
    await repository.clear();

    expect(await repository.load(), isNull);
  });
}