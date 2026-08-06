import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import '../journal_repository.dart';

/// Metadata for JSON → Drift migration (not executed in production by default).
class JournalDriftMigrationState {
  const JournalDriftMigrationState({
    required this.status,
    this.sourceChecksum,
    this.rowCount,
    this.completedAt,
  });

  final String status;
  final String? sourceChecksum;
  final int? rowCount;
  final String? completedAt;

  static const prefsKey = 'journal_drift_migration_v1';
}

/// Encrypted SQLite/Drift foundation — guarded; JSON remains production default.
abstract class DriftJournalDatabase {
  Future<void> open({required String path, required List<int> encryptionKey});
  Future<void> close();
  Future<int> countEntries();
  Future<void> upsertEntries(List<JournalEntry> entries);
  Future<List<JournalEntry>> loadAllIncludingTombstones();
}

/// Idempotent JSON-to-database migration with completion marker written last.
class JsonToDriftJournalMigration {
  JsonToDriftJournalMigration({
    required JournalStore jsonStore,
    required DriftJournalDatabase driftDb,
    required MobilePrefsStore prefs,
  }) : _jsonStore = jsonStore,
       _driftDb = driftDb,
       _prefs = prefs;

  final JournalStore _jsonStore;
  final DriftJournalDatabase _driftDb;
  final MobilePrefsStore _prefs;

  Future<JournalDriftMigrationState> runIfNeeded({
    required String dbPath,
    required List<int> encryptionKey,
  }) async {
    final existing = await _prefs.readJsonMap(JournalDriftMigrationState.prefsKey);
    if (existing?['status'] == 'completed') {
      return JournalDriftMigrationState(
        status: 'completed',
        sourceChecksum: existing?['sourceChecksum'] as String?,
        rowCount: existing?['rowCount'] as int?,
        completedAt: existing?['completedAt'] as String?,
      );
    }

    await _driftDb.open(path: dbPath, encryptionKey: encryptionKey);
    final jsonEntries = await _jsonStore.loadAllIncludingTombstones();
    await _driftDb.upsertEntries(jsonEntries);
    final driftCount = await _driftDb.countEntries();
    if (driftCount != jsonEntries.length) {
      return const JournalDriftMigrationState(status: 'row_count_mismatch');
    }

    final completedAt = DateTime.now().toUtc().toIso8601String();
    final checksum = '${jsonEntries.length}_${jsonEntries.map((e) => e.id).join('|').hashCode}';
    await _prefs.writeJsonMap(JournalDriftMigrationState.prefsKey, {
      'status': 'completed',
      'sourceChecksum': checksum,
      'rowCount': jsonEntries.length,
      'completedAt': completedAt,
    });
    return JournalDriftMigrationState(
      status: 'completed',
      sourceChecksum: checksum,
      rowCount: jsonEntries.length,
      completedAt: completedAt,
    );
  }
}

/// In-memory Drift stand-in for migration tests until codegen schema lands.
class InMemoryDriftJournalDatabase implements DriftJournalDatabase {
  final List<JournalEntry> _rows = [];

  @override
  Future<void> close() async {}

  @override
  Future<int> countEntries() async => _rows.length;

  @override
  Future<List<JournalEntry>> loadAllIncludingTombstones() async =>
      List<JournalEntry>.from(_rows);

  @override
  Future<void> open({required String path, required List<int> encryptionKey}) async {}

  @override
  Future<void> upsertEntries(List<JournalEntry> entries) async {
    final byId = {for (final e in _rows) e.id: e};
    for (final entry in entries) {
      byId[entry.id] = entry;
    }
    _rows
      ..clear()
      ..addAll(byId.values);
  }
}
