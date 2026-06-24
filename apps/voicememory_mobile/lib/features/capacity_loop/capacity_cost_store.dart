import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'capacity_cost_models.dart';

/// Local-only later-cost check-in persistence — entry ids and cost types only.
class CapacityCostStore {
  CapacityCostStore(this._prefs);

  static const prefsKey = 'archiveCapacityCostCheckins';

  final MobilePrefsStore _prefs;

  static List<CapacityCostRecord> _cached = const [];
  static bool _loaded = false;

  static List<CapacityCostRecord> get cached => List.unmodifiable(_cached);

  static CapacityCostStore instance() =>
      CapacityCostStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  Future<List<CapacityCostRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) => CapacityCostRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .whereType<CapacityCostRecord>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<CapacityCostRecord?> recordForEntry(String entryId) async {
    for (final record in await loadAll()) {
      if (record.sourceEntryId == entryId) return record;
    }
    return null;
  }

  CapacityCostRecord? cachedRecordForEntry(String entryId) {
    for (final record in _cached) {
      if (record.sourceEntryId == entryId) return record;
    }
    return null;
  }

  Future<void> saveAnswered({
    required String sourceEntryId,
    required List<String> costTypeIds,
  }) async {
    if (sourceEntryId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = cachedRecordForEntry(sourceEntryId);
    final record = CapacityCostRecord(
      sourceEntryId: sourceEntryId,
      costTypeIds: costTypeIds,
      status: CapacityCostRecordStatus.answered,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _upsert(record);
  }

  Future<void> saveSkipped({required String sourceEntryId}) async {
    if (sourceEntryId.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = cachedRecordForEntry(sourceEntryId);
    final record = CapacityCostRecord(
      sourceEntryId: sourceEntryId,
      costTypeIds: const [],
      status: CapacityCostRecordStatus.skipped,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _upsert(record);
  }

  Future<void> _upsert(CapacityCostRecord record) async {
    final records = [
      for (final existing in await loadAll())
        if (existing.sourceEntryId != record.sourceEntryId) existing,
      record,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist(records);
  }

  Future<void> _persist(List<CapacityCostRecord> records) async {
    await _prefs.writeJsonMap(prefsKey, {
      'records': records.map((record) => record.toJson()).toList(),
    });
    _cached = records;
    _loaded = true;
  }

  static int countWithLaterCost([List<CapacityCostRecord>? records]) =>
      (records ?? _cached).where((record) => record.hasLaterCost).length;

  static bool hasRecordFor(String entryId, [List<CapacityCostRecord>? records]) =>
      (records ?? _cached).any((record) => record.sourceEntryId == entryId);

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
  static void seedForTest(List<CapacityCostRecord> records) {
    _cached = records;
    _loaded = true;
  }
}
