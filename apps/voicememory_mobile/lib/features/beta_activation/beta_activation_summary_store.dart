import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'beta_activation_summary_model.dart';

/// Local-only extension counters for beta activation summary.
class BetaActivationSummaryStore {
  BetaActivationSummaryStore(this._prefs);

  static const countsKey = 'beta_activation_summary_counts_v1';

  static BetaActivationSummaryStore fromAppServices() =>
      BetaActivationSummaryStore(AppServices.instance.prefs);

  static BetaActivationSummaryStore forPrefs(MobilePrefsStore prefs) =>
      BetaActivationSummaryStore(prefs);

  final MobilePrefsStore _prefs;

  Future<BetaActivationSummaryExtension> read() async {
    final map = await _prefs.readMap(countsKey);
    return BetaActivationSummaryExtension.fromMap(map);
  }

  Future<BetaActivationSummaryExtension> increment(String field) async {
    return _prefs
        .updateMap(countsKey, (current) {
          final counts = BetaActivationSummaryExtension.fromMap(current);
          return counts.copyWithIncrement(field).toMap();
        })
        .then(BetaActivationSummaryExtension.fromMap);
  }

  Future<Map<String, int>> exportAggregateCounts() async {
    final values = (await read()).toMap();
    return {
      for (final entry in values.entries)
        if (entry.value is int && (entry.value as int) >= 0)
          entry.key: entry.value as int,
    };
  }

  Future<void> clear() async {
    await _prefs.remove(countsKey);
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    if (prefs == null) return;
    await prefs.remove(countsKey);
  }
}
