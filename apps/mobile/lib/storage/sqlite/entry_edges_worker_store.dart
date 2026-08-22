import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';
import 'package:sqflite/sqflite.dart';

/// Worker-isolate persistence for automated entry graph edges.
final class EntryEdgesWorkerStore {
  EntryEdgesWorkerStore(this._db);

  final Database _db;

  static const edgesTable = Migration013EntryEdges.edgesTable;

  Future<void> replaceSemanticEdges({
    required String sourceEntryId,
    required List<({String targetEntryId, double weight})> edges,
  }) async {
    if (sourceEntryId.isEmpty) return;

    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      await txn.delete(
        edgesTable,
        where: 'source_entry_id = ?',
        whereArgs: [sourceEntryId],
      );

      for (final edge in edges) {
        if (edge.targetEntryId.isEmpty || edge.targetEntryId == sourceEntryId) {
          continue;
        }
        await txn.insert(
          edgesTable,
          {
            'source_entry_id': sourceEntryId,
            'target_entry_id': edge.targetEntryId,
            'relation': Migration013EntryEdges.relationSemanticSimilarity,
            'weight': edge.weight,
            'created_at': nowMillis,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
