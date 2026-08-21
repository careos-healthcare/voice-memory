import 'dart:convert';

import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Allows nullable slim payloads and compacts legacy full JSON blobs.
class Migration007JournalPayloadSlim implements SqliteMigration {
  @override
  int get version => 7;

  @override
  String get id => '007_journal_payload_slim';

  static const table = 'journal_entries';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE journal_entries_v7 (
        id TEXT PRIMARY KEY NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        is_archived INTEGER NOT NULL DEFAULT 0,
        transcript TEXT NOT NULL DEFAULT '',
        has_verified_proof INTEGER NOT NULL DEFAULT 0,
        payload_json TEXT
      )
    ''');

    await db.execute('''
      INSERT INTO journal_entries_v7 (
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      )
      SELECT
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      FROM $table
    ''');

    await db.execute('DROP TABLE $table');
    await db.execute('ALTER TABLE journal_entries_v7 RENAME TO $table');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_entries_active_created_at
      ON $table(created_at DESC)
      WHERE deleted_at IS NULL
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_entries_transcript
      ON $table(transcript COLLATE NOCASE)
      WHERE deleted_at IS NULL
    ''');

    await _compactLegacyPayloads(db);
  }

  Future<void> _compactLegacyPayloads(DatabaseExecutor db) async {
    final rows = await db.query(table, columns: ['id', 'payload_json']);
    for (final row in rows) {
      final payloadJson = row['payload_json'] as String?;
      if (payloadJson == null || payloadJson.isEmpty) continue;

      final payload = jsonDecode(payloadJson);
      if (payload is! Map) continue;
      final map = Map<String, dynamic>.from(payload);
      if (!_isLegacyFullPayload(map)) continue;

      map
        ..remove('id')
        ..remove('createdAt')
        ..remove('updatedAt')
        ..remove('deletedAt')
        ..remove('transcript')
        ..remove('isArchived');

      final slimJson = jsonEncode(map);
      await db.update(
        table,
        {'payload_json': slimJson},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  static bool _isLegacyFullPayload(Map<String, dynamic> payload) {
    return payload.containsKey('id') && payload.containsKey('createdAt');
  }
}
