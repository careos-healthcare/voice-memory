import 'dart:io';

import 'package:archiveme_mobile/storage/sqlite/sqlite_connection_pragmas.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('configureConnection sets performance and durability pragmas', () async {
    final tempDir = await Directory.systemTemp.createTemp('sqlite-pragmas');
    addTearDown(() => tempDir.delete(recursive: true));
    final filePath = p.join(tempDir.path, 'pragmas.db');

    final db = await databaseFactoryFfi.openDatabase(
      filePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: SqliteDatabaseInitializer.configureConnection,
      ),
    );
    addTearDown(db.close);

    expect(
      await _readPragma(db, 'cache_size'),
      SqliteConnectionPragmas.cacheSizeKiB,
    );
    expect(await _readPragma(db, 'temp_store'), 2);
    expect(await _readPragmaString(db, 'journal_mode'), 'wal');
    expect(await _readPragma(db, 'synchronous'), 1);
    expect(await _readPragma(db, 'foreign_keys'), 1);
  });
}

Future<int> _readPragma(Database db, String name) async {
  final rows = await db.rawQuery('PRAGMA $name');
  final value = rows.first.values.first;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw StateError('Unexpected PRAGMA $name value: $value');
}

Future<String> _readPragmaString(Database db, String name) async {
  final rows = await db.rawQuery('PRAGMA $name');
  final value = rows.first.values.first;
  return value.toString().toLowerCase();
}
