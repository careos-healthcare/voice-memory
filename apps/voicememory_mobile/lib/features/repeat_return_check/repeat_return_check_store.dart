import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import 'repeat_return_check_models.dart';

/// Local-only repeat intensity checks keyed by entry id — no transcript text.
class RepeatReturnCheckStore {
  RepeatReturnCheckStore(this._prefs);

  static const _prefsKey = 'repeatReturnCheckRecords_v1';

  final MobilePrefsStore _prefs;

  static List<RepeatReturnCheckRecord> _cached = const [];
  static bool _loaded = false;

  static RepeatReturnCheckStore instance() =>
      RepeatReturnCheckStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  static List<RepeatReturnCheckRecord> get cached => _cached;

  Future<List<RepeatReturnCheckRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) => RepeatReturnCheckRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .where((record) => record.entryId.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  RepeatReturnCheckRecord? recordForEntry(String entryId) {
    for (final record in _cached) {
      if (record.entryId == entryId) return record;
    }
    return null;
  }

  Future<void> save(RepeatReturnCheckRecord record) async {
    final records = [
      record,
      ..._cached.where((existing) => existing.entryId != record.entryId),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cached = records;
    _loaded = true;
    await _prefs.writeJsonMap(_prefsKey, {
      'records': records.map((item) => item.toJson()).toList(),
    });
  }

  Future<void> saveChoice({
    required String entryId,
    required RepeatReturnCheckChoice choice,
    required int entryCountAtCapture,
  }) async {
    await save(
      RepeatReturnCheckRecord(
        entryId: entryId,
        choice: choice,
        entryCountAtCapture: entryCountAtCapture,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Updates the in-memory return-check cache immediately for post-save reads.
  void stageChoice({
    required String entryId,
    required RepeatReturnCheckChoice choice,
    required int entryCountAtCapture,
  }) {
    final records = [
      RepeatReturnCheckRecord(
        entryId: entryId,
        choice: choice,
        entryCountAtCapture: entryCountAtCapture,
        createdAt: DateTime.now().toUtc(),
      ),
      ..._cached.where((existing) => existing.entryId != entryId),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cached = records;
    _loaded = true;
  }

  Future<void> dismiss({
    required String entryId,
    required int entryCountAtCapture,
  }) async {
    await save(
      RepeatReturnCheckRecord(
        entryId: entryId,
        dismissed: true,
        entryCountAtCapture: entryCountAtCapture,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  static String latestSavedEntryId(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.isEmpty) return entries.first.id;
    return eligible.last.id;
  }

  static Future<void> clear() async {
    _cached = const [];
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(_prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() => clear();
}
