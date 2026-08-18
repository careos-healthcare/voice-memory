import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_006_image_embeddings.dart';

/// Typed SQLite and journal-mirror constants shared across repositories.
abstract final class DatabaseConstants {
  DatabaseConstants._();

  static const journalEntriesTable = 'journal_entries';
  static const defaultPageSize = 20;
  static const deleteNotInChunkSize = 500;

  static const String ftsTable = Migration005HybridSearch.ftsTable;
  static const String transcriptEmbeddingsTable =
      Migration005HybridSearch.embeddingsTable;
  static const String imageEmbeddingsTable =
      Migration006ImageEmbeddings.embeddingsTable;

  static const captureContextTagJsonPath = r'$.captureContextTag';

  /// JSON keys duplicated in indexed SQLite columns — excluded from payload_json.
  static const journalEntryColumnJsonKeys = {
    'id',
    'createdAt',
    'updatedAt',
    'deletedAt',
    'transcript',
    'isArchived',
  };

  /// [JournalStore.save] first25 source for post-save detail updates.
  static const first25SourcePostSaveDetailUpdate = 'post_save_detail_update';

  /// [JournalStore.save] first25 source for new post-save detail entries.
  static const first25SourcePostSaveDetail = 'post_save_detail';

  /// Analytics capture kind for typed text attached to an existing entry.
  static const captureKindTypedAttach = 'typed_attach';
}
