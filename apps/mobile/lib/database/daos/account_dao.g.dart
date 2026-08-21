// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountIdentitiesTable get accountIdentities =>
      attachedDatabase.accountIdentities;
  $UserRelationshipsTable get userRelationships =>
      attachedDatabase.userRelationships;
  $AccountProStatusTable get accountProStatus =>
      attachedDatabase.accountProStatus;
  AccountDaoManager get managers => AccountDaoManager(this);
}

class AccountDaoManager {
  final _$AccountDaoMixin _db;
  AccountDaoManager(this._db);
  $$AccountIdentitiesTableTableManager get accountIdentities =>
      $$AccountIdentitiesTableTableManager(
        _db.attachedDatabase,
        _db.accountIdentities,
      );
  $$UserRelationshipsTableTableManager get userRelationships =>
      $$UserRelationshipsTableTableManager(
        _db.attachedDatabase,
        _db.userRelationships,
      );
  $$AccountProStatusTableTableManager get accountProStatus =>
      $$AccountProStatusTableTableManager(
        _db.attachedDatabase,
        _db.accountProStatus,
      );
}
