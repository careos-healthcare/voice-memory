import 'package:archiveme_mobile/storage/sqlite/migrations/migration_017_capture_audio_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'support/configure_sqlite_test_ffi.dart';

void main() {
  configureSqliteTestFfi();

  test('migration 017 creates capture_audio_metadata table', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await Migration017CaptureAudioMetadata().up(db);

    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [Migration017CaptureAudioMetadata.tableName],
    );
    expect(rows, isNotEmpty);
  });
}
