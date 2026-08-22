import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('migration 003 creates account_pro_status table', () async {
    final db = await openTestAppSqliteDatabase();

    final tables = await db.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='account_pro_status'",
    );

    expect(tables, hasLength(1));

    final columns = await db.database.rawQuery(
      'PRAGMA table_info(account_pro_status)',
    );
    final names = columns.map((row) => row['name']).toSet();
    expect(names, contains('is_pro'));
    expect(names, contains('synced_from'));
  });
}