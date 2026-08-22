import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only beta proof feedback — one answer per surface per day.
class BetaProofFeedbackStore {
  BetaProofFeedbackStore(this._prefs);

  static const prefsKey = 'betaProofFeedback_v1';

  final MobilePrefsStore _prefs;

  static final Map<BetaProofFeedbackSurface, BetaProofFeedbackRecord> _cached =
      {};
  static bool _loaded = false;

  static BetaProofFeedbackRecord recordFor(BetaProofFeedbackSurface surface) =>
      _cached[surface] ?? BetaProofFeedbackRecord.empty;

  static bool isAnsweredToday(BetaProofFeedbackSurface surface) {
    final record = recordFor(surface);
    final day = record.dateKey;
    return record.answered &&
        day != null &&
        day.isNotEmpty &&
        day == _todayUtc();
  }

  static BetaProofFeedbackStore instance() =>
      BetaProofFeedbackStore(AppServices.instance.prefs);

  static BetaProofFeedbackStore forPrefs(MobilePrefsStore prefs) =>
      BetaProofFeedbackStore(prefs);

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final store = instance();
    final raw = await store._prefs.readMap(prefsKey);
    _hydrateFromRaw(raw);
    _loaded = true;
  }

  static void _hydrateFromRaw(Map<String, dynamic>? raw) {
    _cached.clear();
    if (raw == null || raw.isEmpty) return;
    final answers = raw['answers'];
    if (answers is! Map) return;
    for (final surface in BetaProofFeedbackSurface.values) {
      final entry = answers[surface.storageValue];
      if (entry is Map<String, dynamic>) {
        _cached[surface] = BetaProofFeedbackRecord.fromJson(entry);
      } else if (entry is Map) {
        _cached[surface] = BetaProofFeedbackRecord.fromJson(
          Map<String, dynamic>.from(entry),
        );
      }
    }
  }

  Future<void> saveAnswer({
    required BetaProofFeedbackSurface surface,
    required BetaProofFeedbackType feedbackType,
    required int entryCount,
  }) async {
    final day = _todayUtc();
    final record = BetaProofFeedbackRecord(
      feedbackType: feedbackType,
      dateKey: day,
      surface: surface,
      entryCount: entryCount,
      answeredAt: DateTime.now().toUtc(),
    );
    _cached[surface] = record;
    _loaded = true;
    final answers = <String, dynamic>{
      for (final item in BetaProofFeedbackSurface.values)
        item.storageValue: (_cached[item] ?? BetaProofFeedbackRecord.empty)
            .toJson(),
    };
    await _prefs.writeMap(prefsKey, {'answers': answers});
  }

  static String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cached.clear();
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}