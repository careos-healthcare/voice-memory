import 'package:archiveme_mobile/storage/sqlite/migrations/migration_001_user_relationships.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_002_fact_ledger.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_003_account_pro_status.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_004_journal_entries.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_007_journal_payload_slim.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Applies pending SQLite migrations in ascending version order.
class SqliteMigrationRunner {
  SqliteMigrationRunner({List<SqliteMigration>? migrations})
      : _migrations = migrations ?? _defaultMigrations;

  static const schemaMigrationsTable = 'schema_migrations';

  static final List<SqliteMigration> _defaultMigrations = [
    Migration001UserRelationships(),
    Migration002FactLedger(),
    Migration003AccountProStatus(),
    Migration004JournalEntries(),
    Migration005HybridSearch(),
    Migration006ImageEmbeddings(),
    Migration007JournalPayloadSlim(),
  ];

  final List<SqliteMigration> _migrations;

  Future<void> run(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $schemaMigrationsTable (
        version INTEGER PRIMARY KEY NOT NULL,
        id TEXT NOT NULL,
        applied_at INTEGER NOT NULL
      )
    ''');

    final appliedRows = await db.query(schemaMigrationsTable);
    final appliedVersions = appliedRows
        .map((row) => row['version'])
        .whereType<int>()
        .toSet();

    final pending = _migrations
        .where((migration) => !appliedVersions.contains(migration.version))
        .toList()
      ..sort((a, b) => a.version.compareTo(b.version));

    for (final migration in pending) {
      await db.transaction((txn) async {
        await migration.up(txn);
        await txn.insert(schemaMigrationsTable, {
          'version': migration.version,
          'id': migration.id,
          'applied_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        });
      });
    }
  }
}
