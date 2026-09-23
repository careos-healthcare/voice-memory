import 'dart:io';

import 'package:archiveme_mobile/core/database/vector_store.dart';
import 'package:archiveme_mobile/core/diagnostics/database_health_service.dart';
import 'package:archiveme_mobile/core/diagnostics/system_diagnostics_screen.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  test('rolling backups keep the two newest copies', () async {
    final directory = await Directory.systemTemp.createTemp('db-health');
    final live = File('${directory.path}/archive.db');
    final health = DatabaseHealthService();
    await _writeMarker(live.path, 'one');
    await health.retainRollingBackup(live);
    await _writeMarker(live.path, 'two');
    await health.retainRollingBackup(live);

    expect(await _readMarker('${directory.path}/archive_me_backup_1.db'), 'two');
    expect(await _readMarker('${directory.path}/archive_me_backup_2.db'), 'one');
  });

  test('startup restores the newest backup when the index is corrupt', () async {
    final directory = await Directory.systemTemp.createTemp('db-recover');
    final live = File('${directory.path}/archive.db');
    final health = DatabaseHealthService();
    await _writeMarker(live.path, 'keep');
    await health.retainRollingBackup(live);
    await live.writeAsString('not a database');

    final report = await health.runStartupCheck(
      databasePath: live.path,
      openDatabase: databaseFactory.openDatabase,
    );

    expect(report.recovered, isTrue);
    expect(report.restoredFrom, 'archive_me_backup_1.db');
    expect(await _readMarker(live.path), 'keep');
  });

  test('a loaded vec index without vec_chunks is inconsistent', () async {
    final directory = await Directory.systemTemp.createTemp('db-vec');
    final db = await databaseFactory.openDatabase('${directory.path}/archive.db');
    addTearDown(db.close);

    final report = await DatabaseHealthService().checkOpen(
      db,
      vecExtensionLoaded: true,
    );

    expect(report.quickCheckOk, isTrue);
    expect(report.vecConsistent, isFalse);
    expect(report.healthy, isFalse);
  });

  test('schema migration keeps a rolling backup beside the database', () async {
    final directory = await Directory.systemTemp.createTemp('db-migrate');
    final db = await databaseFactory.openDatabase('${directory.path}/archive.db');
    addTearDown(db.close);

    await SqliteMigrationManager(migrations: [_MarkerMigration()]).run(db);

    expect(
      File('${directory.path}/archive_me_backup_1.db').existsSync(),
      isTrue,
    );
    expect(DatabaseHealthService.lastReport?.quickCheckOk, isTrue);
  });

  test('vacuum removes orphaned temp files', () async {
    final directory = await Directory.systemTemp.createTemp('db-vacuum');
    final db = await databaseFactory.openDatabase('${directory.path}/archive.db');
    addTearDown(db.close);
    final scratch = Directory('${directory.path}/scratch')..createSync();
    File('${scratch.path}/orphan.tmp').writeAsStringSync('temp');

    final removed = await DatabaseHealthService().vacuumAndReindex(
      database: db,
      scratchDirectory: scratch,
    );

    expect(removed, 1);
    expect(File('${scratch.path}/orphan.tmp').existsSync(), isFalse);
  });

  test('migration history stops at version 20', () {
    expect(
      DatabaseHealthService.migrationHistoryThrough20(23),
      [for (var version = 1; version <= 20; version++) version],
    );
    expect(
      DatabaseHealthService.backgroundTasks(
        lifeMemoEnabled: false,
        meshEnabled: false,
      ).map((task) => task.detail),
      [
        'Not scheduled on this device.',
        'Mesh discovery is off on this device.',
      ],
    );
    expect(VectorStore.scanBudgetBytes, 8 * 1024 * 1024);
  });

  testWidgets('system health shows footprint, schema, and vacuum', (
    tester,
  ) async {
    final history = DatabaseHealthService.migrationHistoryThrough20(23);
    await tester.pumpWidget(
      MaterialApp(
        home: SystemDiagnosticsScreen(
          onVacuum: () async => 2,
          snapshot: DatabaseDiagnosticsSnapshot(
            vectorFootprintBytes: VectorStore.scanBudgetBytes,
            quantizationBits: 4,
            fileSizeBytes: 2048,
            connectionOpen: true,
            schemaVersion: 23,
            migrationHistory: history,
            tasks: DatabaseHealthService.backgroundTasks(
              lifeMemoEnabled: false,
              meshEnabled: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Memory footprint 8 MB'), findsOneWidget);
    expect(find.text('Quantization 4-bit'), findsOneWidget);
    expect(find.text('File size 2 KB'), findsOneWidget);
    expect(find.text('Connection open'), findsOneWidget);
    expect(find.text('Versions 1-20'), findsOneWidget);
    expect(find.text('Schema version 23'), findsOneWidget);
    expect(find.textContaining('Not scheduled on this device.'), findsOneWidget);
    expect(
      find.textContaining('Mesh discovery is off on this device.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('diagnostics_vacuum')));
    await tester.pump();
    expect(find.text('Vacuum finished. Removed 2 temp files.'), findsOneWidget);
  });
}

Future<void> _writeMarker(String path, String value) async {
  final db = await databaseFactory.openDatabase(path);
  await db.execute(
    'CREATE TABLE IF NOT EXISTS marker (id INTEGER PRIMARY KEY, value TEXT)',
  );
  await db.delete('marker');
  await db.insert('marker', {'value': value});
  await db.close();
}

Future<String?> _readMarker(String path) async {
  final db = await databaseFactory.openDatabase(path);
  final rows = await db.query('marker');
  await db.close();
  return rows.single['value'] as String?;
}

class _MarkerMigration implements SqliteMigration {
  @override
  int get version => 1;

  @override
  String get id => '001_marker';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE marker (value TEXT)');
  }
}
