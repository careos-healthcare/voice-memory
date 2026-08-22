import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/pro_status_sqlite_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/storage/sqlite/support/sqlite_test_database.dart';

/// SQLite pro-status smoke tests.
///
/// Run from apps/mobile: `flutter test tool/run_pro_status_self_test.dart`
///
/// These must run on the Flutter test target, not `dart run`: the storage
/// layer transitively imports `package:flutter`, which the bare Dart VM cannot
/// compile because `dart:ui` does not exist there. Under `dart run` the
/// unresolved `dart:ui` types also crash the kernel FFI transformer
/// ("InvalidType is not a subtype of FunctionType"), and `assert` is disabled
/// so every check below would silently pass.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('pro entitlements survive a save/load/clear cycle', () async {
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
    expect(loaded, isNotNull);
    expect(loaded!.entitlements.isPro, isTrue);
    expect(loaded.syncedFrom, 'revenuecat');

    await repository.clear();
    expect(await repository.load(), isNull);
  });
}