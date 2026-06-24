import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'capacity_decision_outcome_models.dart';

/// Local-only decision outcome persistence — entry ids and outcome ids only.
class CapacityDecisionOutcomeStore {
  CapacityDecisionOutcomeStore(this._prefs);

  static const prefsKey = 'archiveCapacityDecisionOutcomes';

  final MobilePrefsStore _prefs;

  static List<CapacityDecisionOutcomeRecord> _cached = const [];
  static bool _loaded = false;

  static List<CapacityDecisionOutcomeRecord> get cached =>
      List.unmodifiable(_cached);

  static CapacityDecisionOutcomeStore instance() =>
      CapacityDecisionOutcomeStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  Future<List<CapacityDecisionOutcomeRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) => CapacityDecisionOutcomeRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .whereType<CapacityDecisionOutcomeRecord>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<CapacityDecisionOutcomeRecord?> recordForEntry(String entryId) async {
    for (final record in await loadAll()) {
      if (record.sourceEntryId == entryId) return record;
    }
    return null;
  }

  CapacityDecisionOutcomeRecord? cachedRecordForEntry(String entryId) {
    for (final record in _cached) {
      if (record.sourceEntryId == entryId) return record;
    }
    return null;
  }

  Future<void> saveAnswered({
    required String sourceEntryId,
    required String outcomeId,
  }) async {
    if (sourceEntryId.isEmpty || outcomeId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = cachedRecordForEntry(sourceEntryId);
    final record = CapacityDecisionOutcomeRecord(
      sourceEntryId: sourceEntryId,
      outcomeId: outcomeId,
      status: CapacityDecisionOutcomeStatus.answered,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _upsert(record);
  }

  Future<void> saveSkipped({required String sourceEntryId}) async {
    if (sourceEntryId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = cachedRecordForEntry(sourceEntryId);
    final record = CapacityDecisionOutcomeRecord(
      sourceEntryId: sourceEntryId,
      outcomeId: '',
      status: CapacityDecisionOutcomeStatus.skipped,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _upsert(record);
  }

  Future<void> _upsert(CapacityDecisionOutcomeRecord record) async {
    final records = [
      for (final existing in await loadAll())
        if (existing.sourceEntryId != record.sourceEntryId) existing,
      record,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist(records);
  }

  Future<void> _persist(List<CapacityDecisionOutcomeRecord> records) async {
    await _prefs.writeJsonMap(prefsKey, {
      'records': records.map((record) => record.toJson()).toList(),
    });
    _cached = records;
    _loaded = true;
  }

  static int countWithOutcome([List<CapacityDecisionOutcomeRecord>? records]) =>
      (records ?? _cached).where((record) => record.hasOutcome).length;

  static bool hasRecordFor(
    String entryId, [
    List<CapacityDecisionOutcomeRecord>? records,
  ]) =>
      (records ?? _cached).any((record) => record.sourceEntryId == entryId);

  static bool hasAnyPatternChange([
    List<CapacityDecisionOutcomeRecord>? records,
  ]) =>
      (records ?? _cached).any((record) => record.showsPatternChange);

  static Future<void> clearAll() async {
    _cached = const [];
    _loaded = true;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _cached = const [];
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(prefsKey, {});
  }

  @visibleForTesting
  static void seedForTest(List<CapacityDecisionOutcomeRecord> records) {
    _cached = records;
    _loaded = true;
  }
}
