import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_store.dart'
    show FactLedgerStore;
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';

/// SQLite mirror for [FactLedgerStore] — powers live badge counts.
class FactLedgerSqliteRepository {
  FactLedgerSqliteRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;
  AppDatabase? _drift;
  FactLedgerDao? _dao;

  FactLedgerDao get _factLedgerDao =>
      _dao ??= FactLedgerDao(_driftDb);

  AppDatabase get _driftDb =>
      _drift ??= AppDatabase.fromSqflite(_sqlite.database);

  bool _backfilledFromPrefs = false;

  static FactLedgerSqliteRepository? fromAppServicesDatabase(
    AppSqliteDatabase? sqlite,
  ) {
    if (sqlite == null) return null;
    return FactLedgerSqliteRepository(sqlite);
  }

  Future<void> ensureBackfilledFromPrefs(MobilePrefsStore prefs) async {
    if (_backfilledFromPrefs) return;
    final raw = await prefs.readMap('archiveFacts');
    if (raw != null) {
      for (final value in raw.values) {
        if (value is! Map) continue;
        final fact = ArchiveFact.fromJson(Map<String, dynamic>.from(value));
        if (fact.id.isEmpty) continue;
        await upsert(fact);
      }
    }
    _backfilledFromPrefs = true;
  }

  Future<void> upsert(ArchiveFact fact) => _factLedgerDao.upsert(fact);

  Future<void> delete(String id) => _factLedgerDao.deleteById(id);

  Future<int> countFacts() => _factLedgerDao.countFacts();

  Future<int> countDistinctEntries() => _factLedgerDao.countDistinctEntries();

  Future<List<ArchiveFact>> forEntry(String sourceEntryId) =>
      _factLedgerDao.forEntry(sourceEntryId);

  Future<List<ArchiveFact>> loadAll() => _factLedgerDao.loadAll();

  Future<List<ArchiveFact>> loadEvidenceCitations() =>
      _factLedgerDao.loadEvidenceCitations();
}
