import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'early_archive_insight_feedback_models.dart';

/// Local-only early archive insight feedback — no journal text.
class EarlyArchiveInsightFeedbackStore {
  EarlyArchiveInsightFeedbackStore(this._prefs);

  static const _prefsKey = 'earlyArchiveInsightFeedbackRecords';

  final MobilePrefsStore _prefs;

  static List<EarlyArchiveInsightFeedbackRecord> _cached = const [];
  static bool _loaded = false;

  static EarlyArchiveInsightFeedbackStore instance() =>
      EarlyArchiveInsightFeedbackStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  Future<List<EarlyArchiveInsightFeedbackRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) => EarlyArchiveInsightFeedbackRecord.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .where((record) => record.surface.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(EarlyArchiveInsightFeedbackRecord record) async {
    final records = [
      record,
      ..._cached.where((existing) => existing.storageKey != record.storageKey),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _prefs.writeJsonMap(_prefsKey, {
      'records': records.map((item) => item.toJson()).toList(),
    });
    _cached = records;
    _loaded = true;
  }

  static EarlyArchiveInsightFeedbackRecord? latestForKey(String storageKey) {
    for (final record in _cached) {
      if (record.storageKey == storageKey) return record;
    }
    return null;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _cached = const [];
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeJsonMap(_prefsKey, {});
  }
}
