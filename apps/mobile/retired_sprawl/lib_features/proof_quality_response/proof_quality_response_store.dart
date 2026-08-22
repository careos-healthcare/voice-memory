import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Local-only proof quality responses — proof key + surface only.
class ProofQualityResponseStore {
  ProofQualityResponseStore(this._prefs);

  static const prefsKey = 'proofQualityResponse_v1';

  final MobilePrefsStore _prefs;

  static final Map<String, ProofQualityResponseRecord> _cached = {};
  static bool _loaded = false;

  static String recordKey({
    required ProofQualityResponseSurface surface,
    required String proofKey,
  }) => '${surface.storageValue}|$proofKey';

  static ProofQualityResponseRecord recordFor({
    required ProofQualityResponseSurface surface,
    required String proofKey,
  }) =>
      _cached[recordKey(surface: surface, proofKey: proofKey)] ??
      ProofQualityResponseRecord.empty;

  static bool isAnswered({
    required ProofQualityResponseSurface surface,
    required String proofKey,
  }) => recordFor(surface: surface, proofKey: proofKey).answered;

  static bool stillTooVagueFor({
    required ProofQualityResponseSurface surface,
    required String proofKey,
  }) => recordFor(surface: surface, proofKey: proofKey).stillTooVague;

  static ProofQualityResponseStore instance() =>
      ProofQualityResponseStore(AppServices.instance.prefs);

  static ProofQualityResponseStore forPrefs(MobilePrefsStore prefs) =>
      ProofQualityResponseStore(prefs);

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
    for (final entry in answers.entries) {
      final key = entry.key;
      if (key is! String) continue;
      if (entry.value is Map<String, dynamic>) {
        _cached[key] = ProofQualityResponseRecord.fromJson(
          entry.value as Map<String, dynamic>,
        );
      } else if (entry.value is Map) {
        _cached[key] = ProofQualityResponseRecord.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
  }

  Future<void> saveAnswer({
    required ProofQualityResponseSurface surface,
    required String proofKey,
    required ProofQualityResponseAnswerType answerType,
    required ProofQualityFeedbackState feedbackState,
    required int entryCount,
    bool stillTooVague = false,
  }) async {
    final key = recordKey(surface: surface, proofKey: proofKey);
    final record = ProofQualityResponseRecord(
      answerType: answerType,
      feedbackState: feedbackState,
      proofKey: proofKey,
      surface: surface,
      entryCount: entryCount,
      answeredAt: DateTime.now().toUtc(),
      stillTooVague: stillTooVague,
    );
    _cached[key] = record;
    _loaded = true;
    final answers = <String, dynamic>{
      for (final item in _cached.entries) item.key: item.value.toJson(),
    };
    await _prefs.writeMap(prefsKey, {'answers': answers});
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _cached.clear();
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}