import 'package:drift/drift.dart';

/// Drift mirror of the `reflection_embeddings` SQLite table.
@DataClassName('ReflectionEmbeddingRow')
class ReflectionEmbeddings extends Table {
  @override
  String get tableName => 'reflection_embeddings';

  TextColumn get entryId => text().named('entry_id')();
  BlobColumn get embedding => blob()();
  IntColumn get dimensions => integer()();
  TextColumn get contentHash => text().named('content_hash')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {entryId};
}
