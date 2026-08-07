import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../current_relevance/current_relevance_model.dart';
import '../current_relevance/current_relevance_store.dart';
import 'correction_memory_model.dart';

/// Local-only archive corrections keyed by proof ids — never journal text.
class CorrectionMemoryStore {
  CorrectionMemoryStore(this._prefs);

  static const _prefsKey = 'correction_memory_records_v1';

  final MobilePrefsStore _prefs;

  static List<CorrectionMemoryRecord> _cached = const [];
  static bool _loaded = false;

  static CorrectionMemoryStore instance() =>
      CorrectionMemoryStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
    _syncFromCurrentRelevanceIfNeeded();
  }

  static List<CorrectionMemoryRecord> get cached => _cached;

  static CorrectionMemoryRecord? recordFor(String proofKey) {
    if (proofKey.isEmpty) return null;
    for (final record in _cached) {
      if (record.proofKey == proofKey) return record;
    }
    final answer = CurrentRelevanceStore.answerFor(proofKey);
    if (answer == null) return null;
    return CorrectionMemoryRecord(
      proofKey: proofKey,
      state: answer.toCorrectionMemoryState(),
      entryCountAtCapture: _entryCountForProofKey(proofKey),
      hasConfirmedRepeat: false,
      correctedAt: DateTime.now().toUtc(),
    );
  }

  static int _entryCountForProofKey(String proofKey) {
    for (final record in CurrentRelevanceStore.cached) {
      if (record.proofKey == proofKey) {
        return record.entryCountAtCapture;
      }
    }
    return 0;
  }

  static void _syncFromCurrentRelevanceIfNeeded() {
    for (final relevance in CurrentRelevanceStore.cached) {
      if (_cached.any((record) => record.proofKey == relevance.proofKey)) {
        continue;
      }
      _cached = [
        CorrectionMemoryRecord(
          proofKey: relevance.proofKey,
          state: relevance.answer.toCorrectionMemoryState(),
          entryCountAtCapture: relevance.entryCountAtCapture,
          hasConfirmedRepeat: false,
          correctedAt: relevance.createdAt,
        ),
        ..._cached,
      ];
    }
  }

  Future<List<CorrectionMemoryRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) =>
              CorrectionMemoryRecord.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((record) => record.proofKey.isNotEmpty)
        .toList()
      ..sort((a, b) => b.correctedAt.compareTo(a.correctedAt));
  }

  Future<void> saveFromAnswer({
    required String proofKey,
    required CurrentRelevanceAnswer answer,
    required int entryCountAtCapture,
    required bool hasConfirmedRepeat,
  }) async {
    if (proofKey.isEmpty) return;
    final record = CorrectionMemoryRecord(
      proofKey: proofKey,
      state: answer.toCorrectionMemoryState(),
      entryCountAtCapture: entryCountAtCapture,
      hasConfirmedRepeat: hasConfirmedRepeat,
      correctedAt: DateTime.now().toUtc(),
    );
    final records = [
      record,
      ..._cached.where((existing) => existing.proofKey != proofKey),
    ]..sort((a, b) => b.correctedAt.compareTo(a.correctedAt));
    _cached = records;
    _loaded = true;
    await _prefs.writeJsonMap(_prefsKey, {
      'records': records.map((item) => item.toJson()).toList(),
    });
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
