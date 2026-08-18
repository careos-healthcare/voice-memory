import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('migration 002 creates fact_ledger table', () async {
    final db = await AppSqliteDatabase.open(filePath: ':memory:');

    final tables = await db.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='fact_ledger'",
    );

    expect(tables, hasLength(1));

    final columns = await db.database.rawQuery('PRAGMA table_info(fact_ledger)');
    final names = columns.map((row) => row['name']).toSet();
    expect(names, contains('source_entry_id'));
    expect(names, contains('updated_at'));
  });
}