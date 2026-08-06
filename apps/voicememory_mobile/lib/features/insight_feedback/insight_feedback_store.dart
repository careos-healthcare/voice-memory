import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'insight_feedback_models.dart';

/// Local-only insight feedback persistence — no journal text, no uploads.
class InsightFeedbackStore {
  InsightFeedbackStore(this._prefs);

  static const prefsKey = 'archiveInsightFeedbackRecords';

  final MobilePrefsStore _prefs;

  static List<InsightFeedbackRecord> _cached = const [];
  static bool _loaded = false;

  static List<InsightFeedbackRecord> get cached => List.unmodifiable(_cached);

  static InsightFeedbackStore instance() =>
      InsightFeedbackStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  Future<List<InsightFeedbackRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) =>
              InsightFeedbackRecord.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((record) => record.insightId.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveRecord(InsightFeedbackRecord record) async {
    if (record.insightId.isEmpty) return;
    final records = [...await loadAll(), record]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _persist(records);
  }

  Future<void> _persist(List<InsightFeedbackRecord> records) async {
    await _prefs.writeJsonMap(prefsKey, {
      'records': records.map((record) => record.toJson()).toList(),
    });
    _cached = records;
    _loaded = true;
  }

  static InsightFeedbackRecord? latestFor(String insightId) {
    for (final record in _cached) {
      if (record.insightId == insightId) return record;
    }
    return null;
  }

  static int countForChoice(InsightFeedbackChoice choice) =>
      _cached.where((record) => record.choice == choice).length;

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
  static void seedForTest(List<InsightFeedbackRecord> records) {
    _cached = records;
    _loaded = true;
  }
}
