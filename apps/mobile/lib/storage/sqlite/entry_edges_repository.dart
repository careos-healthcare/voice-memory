import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_013_entry_edges.dart';

export 'package:archiveme_mobile/database/daos/entry_edges_dao.dart'
    show EntryEdge;

/// Read access to automated knowledge-graph edges stored in SQLite.
class EntryEdgesRepository {
  EntryEdgesRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;
  AppDatabase? _drift;
  EntryEdgesDao? _dao;

  EntryEdgesDao get _entryEdgesDao =>
      _dao ??= EntryEdgesDao(_driftDb);

  AppDatabase get _driftDb =>
      _drift ??= AppDatabase.fromSqflite(_sqlite.database);

  static const edgesTable = Migration013EntryEdges.edgesTable;

  Future<List<EntryEdge>> readOutgoingEdges(String sourceEntryId) =>
      _entryEdgesDao.readOutgoingEdges(sourceEntryId);
}
