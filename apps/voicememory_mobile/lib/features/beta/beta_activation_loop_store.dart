import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'beta_activation_loop_counts.dart';

/// Persists local first-three-entry funnel counters on device.
class BetaActivationLoopStore {
  BetaActivationLoopStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const countsKey = 'beta_activation_loop_counts_v1';

  static BetaActivationLoopStore fromAppServices() =>
      BetaActivationLoopStore(AppServices.instance.prefs);

  Future<BetaActivationLoopCounts> read() async {
    final map = await _prefs.readMap(countsKey);
    return BetaActivationLoopCounts.fromMap(map);
  }

  Future<BetaActivationLoopCounts> increment(String field) async {
    final next = await _prefs.updateMap(countsKey, (current) {
      final counts = BetaActivationLoopCounts.fromMap(current);
      return counts.copyWithIncrement(field).toMap();
    });
    return BetaActivationLoopCounts.fromMap(next);
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
  Future<void> write(BetaActivationLoopCounts counts) async {
    await _prefs.writeMap(countsKey, counts.toMap());
  }
}
