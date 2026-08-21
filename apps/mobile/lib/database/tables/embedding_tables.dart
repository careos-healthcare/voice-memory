import 'package:archiveme_mobile/database/tables/journal_entries.dart';
import 'package:drift/drift.dart';

/// Transcript embedding blobs (`memory_transcript_embeddings`).
@DataClassName('MemoryTranscriptEmbeddingRow')
class MemoryTranscriptEmbeddings extends Table {
  @override
  String get tableName => 'memory_transcript_embeddings';

  TextColumn get entryId =>
      text().named('entry_id').references(JournalEntries, #id)();
  BlobColumn get embedding => blob()();
  IntColumn get dimensions => integer()();

  @override
  Set<Column<Object>> get primaryKey => {entryId};
}

/// Journal image attachment embeddings (`journal_image_embeddings`).
@TableIndex(name: 'idx_journal_image_embeddings_entry_id', columns: {#entryId})
@DataClassName('JournalImageEmbeddingRow')
class JournalImageEmbeddings extends Table {
  @override
  String get tableName => 'journal_image_embeddings';

  TextColumn get evidenceId => text().named('evidence_id')();
  TextColumn get entryId =>
      text().named('entry_id').references(JournalEntries, #id)();
  BlobColumn get embedding => blob()();
  IntColumn get dimensions => integer()();

  @override
  Set<Column<Object>> get primaryKey => {evidenceId};
}
