import 'package:flutter/foundation.dart';

import '../../models/journal_entry.dart';
import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import 'current_relevance_model.dart';

/// Local-only current relevance answers keyed by proof ids — never journal text.
class CurrentRelevanceStore {
  CurrentRelevanceStore(this._prefs);

  static const _prefsKey = 'current_relevance_records_v1';

  final MobilePrefsStore _prefs;

  static List<CurrentRelevanceRecord> _cached = const [];
  static bool _loaded = false;

  static CurrentRelevanceStore instance() =>
      CurrentRelevanceStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().loadAll();
    _loaded = true;
  }

  static List<CurrentRelevanceRecord> get cached => _cached;

  static String proofKeyFor(List<JournalEntry> entries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(entries);
    if (eligible.length < 3) return '';
    final ids = eligible.take(3).map((entry) => entry.id).toList()..sort();
    return ids.join('|');
  }

  static bool hasAnswered(String proofKey) =>
      proofKey.isNotEmpty &&
      _cached.any((record) => record.proofKey == proofKey);

  static CurrentRelevanceAnswer? answerFor(String proofKey) {
    for (final record in _cached) {
      if (record.proofKey == proofKey) return record.answer;
    }
    return null;
  }

  Future<List<CurrentRelevanceRecord>> loadAll() async {
    final raw = await _prefs.readJsonMap(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    final recordsRaw = raw['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map(
          (entry) =>
              CurrentRelevanceRecord.fromJson(Map<String, dynamic>.from(entry)),
        )
        .where((record) => record.proofKey.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveSelection({
    required String proofKey,
    required CurrentRelevanceAnswer answer,
    required int entryCountAtCapture,
  }) async {
    if (proofKey.isEmpty) return;
    final record = CurrentRelevanceRecord(
      proofKey: proofKey,
      answer: answer,
      entryCountAtCapture: entryCountAtCapture,
      createdAt: DateTime.now().toUtc(),
    );
    final records = [
      record,
      ..._cached.where((existing) => existing.proofKey != proofKey),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
