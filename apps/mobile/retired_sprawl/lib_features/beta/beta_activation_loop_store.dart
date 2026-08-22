import 'package:archiveme_mobile/features/beta/beta_activation_loop_counts.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Persists local first-three-entry funnel counters on device.
class BetaActivationLoopStore {
  BetaActivationLoopStore(this._prefs);

  final MobilePrefsStore _prefs;
  static const _countsKey = 'beta_activation_loop_counts_v1';

  static BetaActivationLoopStore fromAppServices() =>
      BetaActivationLoopStore(AppServices.instance.prefs);

  Future<BetaActivationLoopCounts> read() async {
    final map = await _prefs.readMap(_countsKey);
    return BetaActivationLoopCounts.fromMap(map);
  }

  Future<BetaActivationLoopCounts> increment(String field) async {
    final next = await _prefs.updateMap(_countsKey, (current) {
      final counts = BetaActivationLoopCounts.fromMap(current);
      return counts.copyWithIncrement(field).toMap();
    });
    return BetaActivationLoopCounts.fromMap(next);
  }

  Future<void> clear() async {
    await _prefs.writeMap(_countsKey, {});
  }

  @visibleForTesting
  Future<void> write(BetaActivationLoopCounts counts) async {
    await _prefs.writeMap(_countsKey, counts.toMap());
  }
}