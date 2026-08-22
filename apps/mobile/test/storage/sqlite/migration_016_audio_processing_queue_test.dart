import 'package:archiveme_mobile/storage/sqlite/migrations/migration_016_audio_processing_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'support/configure_sqlite_test_ffi.dart';

void main() {
  configureSqliteTestFfi();

  test('migration 016 creates audio_processing_queue table', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await Migration016AudioProcessingQueue().up(db);

    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [Migration016AudioProcessingQueue.tableName],
    );
    expect(rows, isNotEmpty);
  });
}
