import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:sqflite/sqflite.dart';

export 'package:archiveme_mobile/database/daos/reflection_graph_dao.dart'
    show ReflectionGraphSearchHit;

/// SQLite persistence + FTS5 search for offline reflection knowledge graphs.
class ReflectionKnowledgeGraphRepository {
  ReflectionKnowledgeGraphRepository(Database db)
      : _dao = ReflectionGraphDao(AppDatabase.fromSqflite(db));

  ReflectionKnowledgeGraphRepository.fromAppDatabase(AppDatabase db)
      : _dao = db.reflectionGraphDao;

  final ReflectionGraphDao _dao;

  static const nodesTable = ReflectionGraphDao.nodesTable;
  static const ftsTable = ReflectionGraphDao.ftsTable;

  Future<void> replaceGraph(OfflineReflectionKnowledgeGraph graph) =>
      _dao.replaceGraph(graph);

  Future<void> replaceGraphTxn(
    Transaction txn,
    OfflineReflectionKnowledgeGraph graph,
  ) =>
      _dao.replaceGraphInTransaction(graph);

  Future<void> deleteForEntry(String entryId) => _dao.deleteForEntry(entryId);

  Future<void> deleteForEntryTxn(Transaction txn, String entryId) =>
      _dao.deleteForEntry(entryId);

  Future<List<ReflectionGraphSearchHit>> searchNodes({
    required String query,
    int limit = 20,
  }) =>
      _dao.searchNodes(query: query, limit: limit);

  Future<List<String>> searchEntryIds({
    required String query,
    int limit = 20,
  }) =>
      _dao.searchEntryIds(query: query, limit: limit);

  Future<void> syncFromJournalEntry({
    required String entryId,
    required String? tensionOrContradiction,
    required String? nextSmallAction,
    List<String> recurringThemes = const [],
  }) async {
    final graph = OfflineReflectionKnowledgeGraph.fromReflectionFields(
      entryId: entryId,
      tensionOrContradiction: tensionOrContradiction,
      nextSmallAction: nextSmallAction,
      recurringThemes: recurringThemes,
    );
    if (graph.nodes.length <= 1) {
      await deleteForEntry(entryId);
      return;
    }
    await replaceGraph(graph);
  }

  static Future<void> deleteAbsentEntries(
    Database db, {
    required Set<String> keepEntryIds,
  }) =>
      ReflectionGraphDao(AppDatabase.fromSqflite(db)).deleteAbsentEntries(
        keepEntryIds,
      );
}
