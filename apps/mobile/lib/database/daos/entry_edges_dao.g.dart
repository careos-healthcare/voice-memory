// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_edges_dao.dart';

// ignore_for_file: type=lint
mixin _$EntryEdgesDaoMixin on DatabaseAccessor<AppDatabase> {
  $EntryEdgesTable get entryEdges => attachedDatabase.entryEdges;
  EntryEdgesDaoManager get managers => EntryEdgesDaoManager(this);
}

class EntryEdgesDaoManager {
  final _$EntryEdgesDaoMixin _db;
  EntryEdgesDaoManager(this._db);
  $$EntryEdgesTableTableManager get entryEdges =>
      $$EntryEdgesTableTableManager(_db.attachedDatabase, _db.entryEdges);
}
