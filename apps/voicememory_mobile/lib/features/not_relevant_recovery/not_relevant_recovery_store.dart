import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'not_relevant_recovery_copy.dart';
import 'not_relevant_recovery_model.dart';

/// Local-only not-relevant recovery actions — proof key only.
class NotRelevantRecoveryStore {
  NotRelevantRecoveryStore(this._prefs);

  static const prefsKey = 'notRelevantRecovery_v1';

  final MobilePrefsStore _prefs;

  static final Map<String, NotRelevantRecoveryRecord> _cached = {};
  static bool _loaded = false;

  static NotRelevantRecoveryRecord recordFor(String proofKey) =>
      _cached[proofKey] ?? NotRelevantRecoveryRecord.empty;

  static bool isAnswered(String proofKey) => recordFor(proofKey).answered;

  static NotRelevantRecoveryStore instance() =>
      NotRelevantRecoveryStore(AppServices.instance.prefs);

  static NotRelevantRecoveryStore forPrefs(MobilePrefsStore prefs) =>
      NotRelevantRecoveryStore(prefs);

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
      if (entry.value is Map<String, dynamic>) {
        _cached[entry.key] =
            NotRelevantRecoveryRecord.fromJson(entry.value as Map<String, dynamic>);
      } else if (entry.value is Map) {
        _cached[entry.key] = NotRelevantRecoveryRecord.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
      }
    }
  }

  Future<void> saveAction({
    required String proofKey,
    required NotRelevantRecoveryActionType actionType,
    required int entryCount,
  }) async {
    final record = NotRelevantRecoveryRecord(
      actionType: actionType,
      proofKey: proofKey,
      entryCount: entryCount,
      answeredAt: DateTime.now().toUtc(),
    );
    _cached[proofKey] = record;
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
