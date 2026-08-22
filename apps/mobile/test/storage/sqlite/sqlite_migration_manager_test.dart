import 'package:archiveme_mobile/storage/sqlite/migrations/migration_001_user_relationships.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_002_fact_ledger.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_014_embedding_deferred_queue.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sqlite_migration_test_harness.dart';

void main() {
  configureSqliteMigrationTests();

  group('SqliteMigrationRegistry', () {
    test('default migrations are sequential from version 1', () {
      final registry = SqliteMigrationRegistry();
      expect(registry.migrations.first.version, 1);
      expect(
        registry.migrations.last.version,
        SqliteMigrationManager.latestVersion,
      );
      expect(registry.migrations.length, SqliteMigrationManager.latestVersion);
      expect(SqliteMigrationManager.latestVersion, 18);
    });

    test('rejects non-sequential migration versions', () {
      expect(
        () => SqliteMigrationRegistry([
          Migration001UserRelationships(),
          Migration001UserRelationships(),
        ]),
        throwsStateError,
      );
    });
  });

  group('SqliteMigrationManager', () {
    late SqliteMigrationTestHarness harness;

    setUp(() {
      harness = SqliteMigrationTestHarness(
        migrations: [
          Migration001UserRelationships(),
          Migration002FactLedger(),
        ],
      );
    });

    test('starts at user_version 0', () async {
      final db = await harness.openEmpty();
      addTearDown(db.close);
      await harness.expectVersion(db, 0);
    });

    test('applies pending migrations in ascending order inside transactions',
        () async {
      final db = await harness.openEmpty();
      addTearDown(db.close);

      final version = await harness.manager.run(db);
      expect(version, 2);
      await harness.expectVersion(db, 2);
      await harness.expectTableExists(db, 'user_relationships');
      await harness.expectTableExists(db, 'fact_ledger');
    });

    test('runToVersion stops at the requested schema version', () async {
      final db = await harness.openAtVersion(1);
      await harness.expectVersion(db, 1);
      await harness.expectTableExists(db, 'user_relationships');
      await harness.expectTableExists(db, 'fact_ledger', exists: false);
    });

    test('is idempotent when re-run on a fully migrated database', () async {
      final db = await harness.openLatest();
      await harness.expectIdempotent(db);
    });

    test('bootstraps legacy schema_migrations into user_version', () async {
      final db = await harness.openEmpty();
      addTearDown(db.close);

      await db.execute('''
        CREATE TABLE ${SqliteMigrationManager.legacySchemaMigrationsTable} (
          version INTEGER PRIMARY KEY NOT NULL,
          id TEXT NOT NULL,
          applied_at INTEGER NOT NULL
        )
      ''');
      await db.insert(
        SqliteMigrationManager.legacySchemaMigrationsTable,
        {
          'version': 2,
          'id': Migration002FactLedger().id,
          'applied_at': 1,
        },
      );

      await harness.manager.run(db);

      await harness.expectVersion(db, 2);
      await harness.expectTableExists(
        db,
        SqliteMigrationManager.legacySchemaMigrationsTable,
        exists: false,
      );
    });
  });

  group('full migration chain', () {
    test('openLatest reaches latestVersion with core tables present', () async {
      final harness = SqliteMigrationTestHarness();
      final db = await harness.openLatest();

      await harness.expectVersion(db, SqliteMigrationManager.latestVersion);
      await harness.expectTableExists(db, 'journal_entries');
      await harness.expectTableExists(
        db,
        Migration011ReflectionGraphFts.ftsTable,
      );
      await harness.expectTableExists(
        db,
        Migration013EntryEdges.edgesTable,
      );
      await harness.expectTableExists(
        db,
        Migration014EmbeddingDeferredQueue.queueTable,
      );
      await harness.expectIdempotent(db);
    });
  });
}
