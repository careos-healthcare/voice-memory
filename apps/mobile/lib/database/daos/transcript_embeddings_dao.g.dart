// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcript_embeddings_dao.dart';

// ignore_for_file: type=lint
mixin _$TranscriptEmbeddingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $JournalEntriesTable get journalEntries => attachedDatabase.journalEntries;
  $MemoryTranscriptEmbeddingsTable get memoryTranscriptEmbeddings =>
      attachedDatabase.memoryTranscriptEmbeddings;
  $JournalImageEmbeddingsTable get journalImageEmbeddings =>
      attachedDatabase.journalImageEmbeddings;
  TranscriptEmbeddingsDaoManager get managers =>
      TranscriptEmbeddingsDaoManager(this);
}

class TranscriptEmbeddingsDaoManager {
  final _$TranscriptEmbeddingsDaoMixin _db;
  TranscriptEmbeddingsDaoManager(this._db);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(
        _db.attachedDatabase,
        _db.journalEntries,
      );
  $$MemoryTranscriptEmbeddingsTableTableManager
  get memoryTranscriptEmbeddings =>
      $$MemoryTranscriptEmbeddingsTableTableManager(
        _db.attachedDatabase,
        _db.memoryTranscriptEmbeddings,
      );
  $$JournalImageEmbeddingsTableTableManager get journalImageEmbeddings =>
      $$JournalImageEmbeddingsTableTableManager(
        _db.attachedDatabase,
        _db.journalImageEmbeddings,
      );
}
