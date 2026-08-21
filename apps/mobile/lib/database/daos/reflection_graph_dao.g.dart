// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reflection_graph_dao.dart';

// ignore_for_file: type=lint
mixin _$ReflectionGraphDaoMixin on DatabaseAccessor<AppDatabase> {
  $JournalEntriesTable get journalEntries => attachedDatabase.journalEntries;
  $ReflectionGraphNodesTable get reflectionGraphNodes =>
      attachedDatabase.reflectionGraphNodes;
  $AppSqliteMetaTable get appSqliteMeta => attachedDatabase.appSqliteMeta;
  ReflectionGraphDaoManager get managers => ReflectionGraphDaoManager(this);
}

class ReflectionGraphDaoManager {
  final _$ReflectionGraphDaoMixin _db;
  ReflectionGraphDaoManager(this._db);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(
        _db.attachedDatabase,
        _db.journalEntries,
      );
  $$ReflectionGraphNodesTableTableManager get reflectionGraphNodes =>
      $$ReflectionGraphNodesTableTableManager(
        _db.attachedDatabase,
        _db.reflectionGraphNodes,
      );
  $$AppSqliteMetaTableTableManager get appSqliteMeta =>
      $$AppSqliteMetaTableTableManager(_db.attachedDatabase, _db.appSqliteMeta);
}
