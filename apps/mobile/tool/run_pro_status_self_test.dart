import 'dart:io' show stdout;
import 'storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/pro_status_sqlite_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite pro-status smoke tests runnable without compiling the full app.
///
/// Run from apps/mobile: `dart run tool/run_pro_status_self_test.dart`
Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await openTestAppSqliteDatabase();
  final repository = ProStatusSqliteRepository(db);

  const pro = PremiumEntitlements(
    tier: BillingTier.pro,
    entitlementIds: ['archive_loop_pro'],
    billingConnected: true,
    source: 'revenuecat',
  );

  await repository.save(pro, syncedFrom: 'revenuecat');
  final loaded = await repository.load();
  assert(loaded != null && loaded.entitlements.isPro);
  assert(loaded.syncedFrom == 'revenuecat');

  await repository.clear();
  assert(await repository.load() == null);

  await AppSqliteDatabase.resetForTest();
  stdout.writeln('OK: pro status sqlite self-tests passed');
}