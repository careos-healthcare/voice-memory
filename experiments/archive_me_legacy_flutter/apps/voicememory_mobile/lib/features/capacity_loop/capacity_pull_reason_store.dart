import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'capacity_pull_reason_models.dart';

/// Local-only pull reason persistence — entry ids and reason ids only.
class CapacityPullReasonStore {
  CapacityPullReasonStore(this._prefs);

  static const prefsKey = 'archiveCapacityPullReasons';

  final MobilePrefsStore _prefs;

  static List<CapacityPullReasonRecord> _cached = const [];
  static bool _loaded = false;

  static List<CapacityPullReasonRecord> get cached =>
      List.unmodifiable(_cached);

  static CapacityPullReasonStore instance() =>
      CapacityPullReasonStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  Future<List<CapacityPullReasonRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) => CapacityPullReasonRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .whereType<CapacityPullReasonRecord>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  CapacityPullReasonRecord? cachedRecordForEntry(String entryId) {
    for (final record in _cached) {
      if (record.sourceEntryId == entryId) return record;
    }
    return null;
  }

  Future<void> saveAnswered({
    required String sourceEntryId,
    required List<String> reasonIds,
  }) async {
    if (sourceEntryId.isEmpty || reasonIds.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = cachedRecordForEntry(sourceEntryId);
    final record = CapacityPullReasonRecord(
      sourceEntryId: sourceEntryId,
      reasonIds: reasonIds,
      status: CapacityPullReasonStatus.answered,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _upsert(record);
  }

  Future<void> saveSkipped({required String sourceEntryId}) async {
    if (sourceEntryId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = cachedRecordForEntry(sourceEntryId);
    final record = CapacityPullReasonRecord(
      sourceEntryId: sourceEntryId,
      reasonIds: const [],
      status: CapacityPullReasonStatus.skipped,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _upsert(record);
  }

  Future<void> _upsert(CapacityPullReasonRecord record) async {
    final records = [
      for (final existing in await loadAll())
        if (existing.sourceEntryId != record.sourceEntryId) existing,
      record,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist(records);
  }

  Future<void> _persist(List<CapacityPullReasonRecord> records) async {
    await _prefs.writeJsonMap(prefsKey, {
      'records': records.map((record) => record.toJson()).toList(),
    });
    _cached = records;
    _loaded = true;
  }

  static int countWithReason([List<CapacityPullReasonRecord>? records]) =>
      (records ?? _cached).where((record) => record.hasReasons).length;

  static bool hasRecordFor(
    String entryId, [
    List<CapacityPullReasonRecord>? records,
  ]) => (records ?? _cached).any((record) => record.sourceEntryId == entryId);

  static String? mostCommonReasonId([List<CapacityPullReasonRecord>? records]) {
    final counts = <String, int>{};
    for (final record in records ?? _cached) {
      if (!record.hasReasons) continue;
      for (final id in record.reasonIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

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
  static void seedForTest(List<CapacityPullReasonRecord> records) {
    _cached = records;
    _loaded = true;
  }
}
