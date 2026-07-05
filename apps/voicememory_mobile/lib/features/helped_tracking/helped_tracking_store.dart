import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'helped_tracking_model.dart';

/// Local-only helped markers keyed by entry id — free text stays on device.
class HelpedTrackingStore {
  HelpedTrackingStore(this._prefs);

  static const _prefsKey = 'helped_tracking_records_v1';
  static const maxFreeTextLength = 120;

  final MobilePrefsStore _prefs;

  static List<HelpedTrackingRecord> _cached = const [];
  static bool _loaded = false;

  static HelpedTrackingStore instance() =>
      HelpedTrackingStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  static List<HelpedTrackingRecord> get cached => _cached;

  Future<List<HelpedTrackingRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) => HelpedTrackingRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .where((record) => record.entryId.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  HelpedTrackingRecord? recordForEntry(String entryId) {
    for (final record in _cached) {
      if (record.entryId == entryId) return record;
    }
    return null;
  }

  Future<void> save(HelpedTrackingRecord record) async {
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

  Future<void> saveSelection({
    required String entryId,
    required HelpedTrackingOption option,
    required int entryCountAtCapture,
    String? freeText,
  }) async {
    await save(
      HelpedTrackingRecord(
        entryId: entryId,
        option: option,
        freeText: normalizeFreeText(freeText),
        entryCountAtCapture: entryCountAtCapture,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @visibleForTesting
  static String? normalizeFreeText(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxFreeTextLength) return trimmed;
    return trimmed.substring(0, maxFreeTextLength).trimRight();
  }

  static Future<void> clearAll() async {
    _cached = const [];
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(_prefsKey, {});
  }

  @visibleForTesting
  static void invalidateCache() {
    _cached = const [];
    _loaded = false;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    await clearAll();
  }
}
