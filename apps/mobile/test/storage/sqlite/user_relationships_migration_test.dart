import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_001_user_relationships.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_002_fact_ledger.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../storage/sqlite/support/sqlite_test_database.dart';

import 'support/sqlite_migration_test_harness.dart';

void main() {
  configureSqliteMigrationTests();

  tearDown(AppSqliteDatabase.resetForTest);

  test('migration 001 creates user_relationships with foreign keys', () async {
    final db = await openTestAppSqliteDatabase();
    final database = db.database;

    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final tableNames = tables.map((row) => row['name']).toSet();
    expect(tableNames, contains('user_relationships'));
    expect(tableNames, contains('account_identities'));
    expect(
      tableNames,
      isNot(contains(SqliteMigrationManager.legacySchemaMigrationsTable)),
    );

    final versionRows = await database.rawQuery('PRAGMA user_version');
    expect(versionRows.single['user_version'], SqliteMigrationManager.latestVersion);

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

  test('migration manager is idempotent', () async {
    final harness = SqliteMigrationTestHarness(
      migrations: [
        Migration001UserRelationships(),
        Migration002FactLedger(),
      ],
    );
    final database = await harness.openLatest();
    await harness.expectVersion(database, 2);

    await harness.manager.run(database);
    await harness.expectVersion(database, 2);

    await harness.manager.run(database);
    await harness.expectVersion(database, 2);
  });
}
