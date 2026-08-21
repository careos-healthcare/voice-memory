import 'dart:convert';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:sqflite/sqflite.dart';

/// One-time backfill of reflection graph nodes + FTS rows from journal payloads.
abstract final class ReflectionGraphBackfill {
  ReflectionGraphBackfill._();

  static const metaTable = 'app_sqlite_meta';
  static const backfillCompleteKey = 'reflection_graph_backfill_v1';

  static const _nodesTable = Migration011ReflectionGraphFts.nodesTable;
  static const _ftsTable = Migration011ReflectionGraphFts.ftsTable;

  /// Whether graph tables still need the one-time journal backfill.
  static Future<bool> isPending(DatabaseExecutor db) async {
    if (await _hasCompletionFlag(db)) {
      return false;
    }

    final nodeCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_nodesTable'),
        ) ??
        0;
    if (nodeCount > 0) {
      await markComplete(db);
      return false;
    }

    return true;
  }

  static Future<void> markComplete(DatabaseExecutor db) async {
    if (!await _tableExists(db, metaTable)) {
      return;
    }
    await db.insert(
      metaTable,
      {'key': backfillCompleteKey, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<bool> _hasCompletionFlag(DatabaseExecutor db) async {
    if (!await _tableExists(db, metaTable)) {
      return false;
    }
    final rows = await db.query(
      metaTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [backfillCompleteKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  /// Builds graph nodes from active journal rows and inserts into graph tables.
  ///
  /// Returns the number of journal entries that received at least one graph node.
  static Future<int> fromJournalEntries(DatabaseExecutor db) async {
    final rows = await db.query(
      DatabaseConstants.journalEntriesTable,
      columns: ['id', 'payload_json'],
      where: 'deleted_at IS NULL',
    );
    if (rows.isEmpty) {
      return 0;
    }

    final updatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    var entryCount = 0;

    for (final row in rows) {
      final entryId = row['id'] as String? ?? '';
      if (entryId.isEmpty) {
        continue;
      }

      final reflection = reflectionFromPayload(row['payload_json'] as String?);
      if (reflection == null) {
        continue;
      }

      final graph = OfflineReflectionKnowledgeGraph.fromReflectionFields(
        entryId: entryId,
        tensionOrContradiction: reflection.tensionOrContradiction,
        nextSmallAction: reflection.nextSmallAction,
        recurringThemes: reflection.recurringThemes,
      );
      if (graph.nodes.length <= 1) {
        continue;
      }

      for (final node in graph.nodes) {
        batch.insert(_nodesTable, {
          'id': node.id,
          'entry_id': entryId,
          'kind': node.kind,
          'label': node.label,
          'payload_json':
              node.payload.isEmpty ? null : jsonEncode(node.payload),
          'updated_at': updatedAt,
        });
        batch.insert(_ftsTable, {
          'node_id': node.id,
          'entry_id': entryId,
          'kind': node.kind,
          'label': node.label,
        });
      }
      entryCount++;
    }

    if (entryCount > 0) {
      await batch.commit(noResult: true);
    }
    return entryCount;
  }

  /// Parses reflection fields from slim or legacy full [payloadJson] blobs.
  static Reflection? reflectionFromPayload(String? payloadJson) {
    if (payloadJson == null || payloadJson.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) {
        return null;
      }
      final payload = Map<String, dynamic>.from(decoded);
      final reflectionJson = payload['reflection'];
      if (reflectionJson is! Map) {
        return null;
      }
      return Reflection.fromJson(Map<String, dynamic>.from(reflectionJson));
    } on Object {
      return null;
    }
  }
}
