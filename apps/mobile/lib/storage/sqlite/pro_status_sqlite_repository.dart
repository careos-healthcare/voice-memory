import 'dart:convert';

import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/models/entitlement.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';

export 'package:archiveme_mobile/database/daos/account_dao.dart' show ProStatusRecord;

/// Local SQLite mirror of the account Pro/Free entitlement snapshot.
class ProStatusSqliteRepository {
  ProStatusSqliteRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;
  AppDatabase? _drift;

  AppDatabase get _db => _drift ??= AppDatabase.fromSqflite(_sqlite.database);

  Future<ProStatusRecord?> load() => _db.accountDao.loadProStatus();

  Future<void> save(
    PremiumEntitlements entitlements, {
    required String syncedFrom,
  }) =>
      _db.accountDao.saveProStatus(entitlements, syncedFrom: syncedFrom);

  Future<void> clear() => _db.accountDao.clearProStatus();
}
