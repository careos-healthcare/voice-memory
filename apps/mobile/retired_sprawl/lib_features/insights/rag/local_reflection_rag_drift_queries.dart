import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:drift/drift.dart';

/// Drift queries over the local journal + reflection embedding tables.
abstract final class LocalReflectionRagDriftQueries {
  LocalReflectionRagDriftQueries._();

  static Future<List<({String entryId, DateTime updatedAt})>>
  fetchIndexedReflectionEntryIds(
    JournalDatabase db, {
    int limit = 32,
  }) async {
    final rows = await db.customSelect(
      '''
      SELECT entry_id, updated_at
      FROM reflection_embeddings
      ORDER BY updated_at DESC
      LIMIT ?
      ''',
      variables: [Variable<int>(limit)],
      readsFrom: {db.reflectionEmbeddings},
    ).get();

    return rows
        .map((row) {
          final entryId = row.read<String>('entry_id');
          final updatedAtMillis = row.read<int>('updated_at');
          if (entryId == null || updatedAtMillis == null) return null;
          return (
            entryId: entryId,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              updatedAtMillis,
              isUtc: true,
            ),
          );
        })
        .whereType<({String entryId, DateTime updatedAt})>()
        .toList(growable: false);
  }

  static Future<int> countIndexedReflections(JournalDatabase db) async {
    final count = db.reflectionEmbeddings.entryId.count();
    final row = await (db.selectOnly(db.reflectionEmbeddings)
          ..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }
}
