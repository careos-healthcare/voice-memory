import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'beta_repair_lab_copy.dart';
import 'beta_repair_lab_model.dart';

/// Local-only active repair mode for beta/testing rounds.
abstract final class BetaRepairLabStore {
  BetaRepairLabStore._();

  static const prefsKey = 'betaRepairLabMode_v1';

  static BetaRepairLabMode _mode = BetaRepairLabMode.none;
  static bool _loaded = false;

  static BetaRepairLabMode get mode => _mode;

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final raw = await AppServices.instance.prefs.readMap(prefsKey);
    _mode = _parseMode(raw?['selectedMode']);
    _loaded = true;
  }

  static Future<BetaRepairLabMode> selectMode(
    BetaRepairLabMode mode, {
    required String source,
  }) async {
    final previous = _mode;
    _mode = mode;
    _loaded = true;
    if (!AppServices.isInitialized) return previous;
    await AppServices.instance.prefs.writeMap(prefsKey, {
      'selectedMode': mode.analyticsValue,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'source': source,
    });
    return previous;
  }

  static Future<BetaRepairLabMode> clearMode({required String source}) async {
    return selectMode(BetaRepairLabMode.none, source: source);
  }

  static BetaRepairLabMode _parseMode(Object? raw) {
    if (raw is! String || raw.isEmpty) return BetaRepairLabMode.none;
    for (final mode in BetaRepairLabMode.values) {
      if (mode.analyticsValue == raw) return mode;
    }
    return BetaRepairLabMode.none;
  }

  @visibleForTesting
  static Future<void> setModeForTest(
    BetaRepairLabMode mode, {
    MobilePrefsStore? prefs,
  }) async {
    _mode = mode;
    _loaded = true;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {
      'selectedMode': mode.analyticsValue,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'source': 'test',
    });
  }

  @visibleForTesting
  static Future<void> resetForTest(MobilePrefsStore? prefs) async {
    _mode = BetaRepairLabMode.none;
    _loaded = false;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}
