import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_021_ambient_metadata.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes the `ambient_metadata` JSON column on journal entries.
abstract final class AmbientMetadataStore {
  static Future<void> write(
    DatabaseExecutor db, {
    required String entryId,
    required AmbientMetadata metadata,
  }) async {
    await db.update(
      Migration021AmbientMetadata.journalEntriesTable,
      {Migration021AmbientMetadata.column: metadata.encode()},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  static Future<AmbientMetadata?> read(
    DatabaseExecutor db,
    String entryId,
  ) async {
    try {
      final rows = await db.query(
        Migration021AmbientMetadata.journalEntriesTable,
        columns: [Migration021AmbientMetadata.column],
        where: 'id = ?',
        whereArgs: [entryId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final raw = rows.single[Migration021AmbientMetadata.column];
      return AmbientMetadata.decode(raw as String?);
    } on Object {
      return null;
    }
  }
}
