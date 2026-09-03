import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_knowledge_graph_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Bulk journal mirror writes shared by the repository and background isolates.
abstract final class JournalSqliteBulkSync {
  JournalSqliteBulkSync._();

  static const table = DatabaseConstants.journalEntriesTable;

  static Future<void> upsertEntries(
    Database db,
    List<JournalEntry> entries,
  ) async {
    if (entries.isEmpty) return;

    final drift = AppDatabase.fromSqflite(db);
    final ids = entries.map((entry) => entry.id).toSet();
    final graphRepo = ReflectionKnowledgeGraphRepository(db);

    await drift.transaction(() async {
      final existingById = await drift.journalDao.loadExistingSyncState(ids);
      for (final entry in entries) {
        await drift.journalDao.upsertJournalEntry(entry);
        await _syncFtsRow(
          drift,
          entry: entry,
          existing: existingById[entry.id],
        );
        await _syncGraphRow(graphRepo: graphRepo, entry: entry);
      }
    });
  }

  static Future<void> mirrorEntireRemoteState(
    Database db,
    List<JournalEntry> entries,
  ) async {
    final drift = AppDatabase.fromSqflite(db);
    final ids = entries.map((entry) => entry.id).toSet();
    final graphRepo = ReflectionKnowledgeGraphRepository(db);

    await drift.transaction(() async {
      if (ids.isEmpty) {
        await drift.delete(drift.journalEntries).go();
        await drift.customStatement(
          'DELETE FROM ${DatabaseConstants.ftsTable}',
        );
        await drift.delete(drift.memoryTranscriptEmbeddings).go();
        await drift.delete(drift.journalImageEmbeddings).go();
        await drift.customStatement(
          'DELETE FROM ${DatabaseConstants.graphNodeFtsTable}',
        );
        await drift.delete(drift.reflectionGraphNodes).go();
        return;
      }

      final existingById = await drift.journalDao.loadExistingSyncState(ids);
      for (final entry in entries) {
        await drift.journalDao.upsertJournalEntry(entry);
        await _syncFtsRow(
          drift,
          entry: entry,
          existing: existingById[entry.id],
        );
        await _syncGraphRow(graphRepo: graphRepo, entry: entry);
      }
      await _deleteAbsentRows(drift, db, ids);
    });
  }

  static Future<void> _syncFtsRow(
    AppDatabase drift, {
    required JournalEntry entry,
    required ExistingJournalSyncState? existing,
  }) async {
    final entryId = entry.id;
    final isDeleted = entry.deletedAt != null;
    final wasDeleted = existing?.deletedAt != null;
    final transcriptChanged =
        existing == null || existing.transcript != entry.transcript;

    if (isDeleted) {
      if (!wasDeleted) {
        await _deleteFtsRow(drift, entryId);
      }
      return;
    }

    if (!transcriptChanged) {
      return;
    }

    await _deleteFtsRow(drift, entryId);
    await drift.customStatement(
      '''
      INSERT INTO ${DatabaseConstants.ftsTable} (entry_id, transcript)
      VALUES (?, ?)
      ''',
      [entryId, entry.transcript],
    );
  }

  static Future<void> _syncGraphRow({
    required ReflectionKnowledgeGraphRepository graphRepo,
    required JournalEntry entry,
  }) async {
    final entryId = entry.id;
    final isDeleted = entry.deletedAt != null;
    if (isDeleted) {
      await graphRepo.deleteForEntry(entryId);
      return;
    }

    final graph = OfflineReflectionKnowledgeGraph.fromReflectionFields(
      entryId: entryId,
      tensionOrContradiction: entry.reflection.tensionOrContradiction,
      nextSmallAction: entry.reflection.nextSmallAction,
      recurringThemes: entry.reflection.recurringThemes,
    );
    if (graph.nodes.length <= 1) {
      await graphRepo.deleteForEntry(entryId);
      return;
    }
    await graphRepo.replaceGraph(graph);
  }

  static Future<void> _deleteFtsRow(AppDatabase drift, String entryId) async {
    await drift.customStatement(
      'DELETE FROM ${DatabaseConstants.ftsTable} WHERE entry_id = ?',
      [entryId],
    );
  }

  static Future<void> _deleteAbsentRows(
    AppDatabase drift,
    Database db,
    Set<String> ids,
  ) async {
    await drift.transcriptEmbeddingsDao.deleteIdsNotIn(
      table: DatabaseConstants.journalEntriesTable,
      keepIds: ids,
    );
    await drift.transcriptEmbeddingsDao.deleteIdsNotIn(
      table: DatabaseConstants.ftsTable,
      keepIds: ids,
      idColumn: 'entry_id',
    );
    await drift.transcriptEmbeddingsDao.deleteIdsNotIn(
      table: DatabaseConstants.transcriptEmbeddingsTable,
      keepIds: ids,
      idColumn: 'entry_id',
    );
    await drift.transcriptEmbeddingsDao.deleteIdsNotIn(
      table: DatabaseConstants.imageEmbeddingsTable,
      keepIds: ids,
      idColumn: 'entry_id',
    );
    await ReflectionKnowledgeGraphRepository.deleteAbsentEntries(
      db,
      keepEntryIds: ids,
    );
  }
}
