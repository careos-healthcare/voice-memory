import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_001_user_relationships.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_002_fact_ledger.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('migration 001 creates user_relationships with foreign keys', () async {
    final db = await AppSqliteDatabase.open(filePath: ':memory:');
    final database = db.database;

    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final tableNames = tables.map((row) => row['name']).toSet();
    expect(tableNames, contains('user_relationships'));
    expect(tableNames, contains('account_identities'));
    expect(tableNames, contains('schema_migrations'));

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await database.insert('account_identities', {
      'id': 'client-1',
      'created_at': now,
    });
    await database.insert('account_identities', {
      'id': 'coach-1',
      'created_at': now,
    });
    await database.insert('user_relationships', {
      'id': 'rel-1',
      'client_id': 'client-1',
      'professional_id': 'coach-1',
      'relationship_type': 'professional',
      'consent_status': 'pending',
      'agreed_scope': '{"factLedger":false}',
      'created_at': now,
      'updated_at': now,
    });

    final rows = await database.query('user_relationships');
    expect(rows, hasLength(1));
    expect(rows.single['consent_status'], 'pending');
  });

  test('migration runner is idempotent', () async {
    final db = await AppSqliteDatabase.open(filePath: ':memory:');
    final database = db.database;

    await SqliteMigrationRunner().run(database);
    await SqliteMigrationRunner().run(database);

    final migrations = await database.query('schema_migrations');
    expect(migrations, hasLength(2));
    expect(
      migrations.map((row) => row['id']).toSet(),
      containsAll([
        Migration001UserRelationships().id,
        Migration002FactLedger().id,
      ]),
    );
  });
}