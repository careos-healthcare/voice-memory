// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fact_ledger_dao.dart';

// ignore_for_file: type=lint
mixin _$FactLedgerDaoMixin on DatabaseAccessor<AppDatabase> {
  $FactLedgerEntriesTable get factLedgerEntries =>
      attachedDatabase.factLedgerEntries;
  FactLedgerDaoManager get managers => FactLedgerDaoManager(this);
}

class FactLedgerDaoManager {
  final _$FactLedgerDaoMixin _db;
  FactLedgerDaoManager(this._db);
  $$FactLedgerEntriesTableTableManager get factLedgerEntries =>
      $$FactLedgerEntriesTableTableManager(
        _db.attachedDatabase,
        _db.factLedgerEntries,
      );
}
