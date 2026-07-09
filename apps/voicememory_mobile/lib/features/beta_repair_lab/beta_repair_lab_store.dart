import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../beta/archive_beta_mission_gate.dart';
import 'beta_repair_lab_copy.dart';
import 'beta_repair_lab_model.dart';

/// Local-only active repair mode for beta/testing rounds.
abstract final class BetaRepairLabStore {
  BetaRepairLabStore._();

  static const prefsKey = 'betaRepairLabMode_v1';
  static const buildRepairModeDefineKey = 'ARCHIVEME_BETA_REPAIR_MODE';

  static const defaultBetaBaselineMode = BetaRepairLabMode.proofSpecificityCaution;

  static const _repairModeFromEnvironment = String.fromEnvironment(
    buildRepairModeDefineKey,
    defaultValue: '',
  );

  @visibleForTesting
  static String? repairModeOverrideForTest;

  static BetaRepairLabMode _mode = BetaRepairLabMode.none;
  static bool _loaded = false;

  /// Locally stored picker selection from the testing screen.
  static BetaRepairLabMode get mode => _mode;

  static BetaRepairLabMode get localMode => _mode;

  /// Effective repair mode: build override, local picker, or beta baseline.
  static BetaRepairLabMode get activeMode {
    if (!ArchiveBetaMissionGate.isEnabled) return BetaRepairLabMode.none;
    if (isBuildOverrideActive) return buildOverrideMode;
    if (_hasInvalidExplicitBuildOverride) return defaultBetaBaselineMode;
    if (_mode != BetaRepairLabMode.none) return _mode;
    return defaultBetaBaselineMode;
  }

  static bool get isBuildOverrideActive =>
      buildOverrideMode != BetaRepairLabMode.none;

  /// Valid explicit dart-define override only — empty/invalid do not count.
  static BetaRepairLabMode get buildOverrideMode {
    if (!ArchiveBetaMissionGate.isEnabled) return BetaRepairLabMode.none;
    if (!_hasExplicitBuildRepairOverride) return BetaRepairLabMode.none;
    return parseBuildRepairMode(_rawBuildRepairMode);
  }

  static bool get isDefaultBaselineActive {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (isBuildOverrideActive) return false;
    return activeMode == defaultBetaBaselineMode;
  }

  static bool get _hasExplicitBuildRepairOverride {
    final normalized = _rawBuildRepairMode.trim();
    return normalized.isNotEmpty && normalized != BetaRepairLabMode.none.name;
  }

  static bool get _hasInvalidExplicitBuildOverride =>
      _hasExplicitBuildRepairOverride &&
      parseBuildRepairMode(_rawBuildRepairMode) == BetaRepairLabMode.none;

  static String get _rawBuildRepairMode =>
      repairModeOverrideForTest ?? _repairModeFromEnvironment;

  static String? get buildOverrideActiveLabel {
    final mode = buildOverrideMode;
    if (mode == BetaRepairLabMode.none) return null;
    return '${BetaRepairLabCopy.buildOverrideActivePrefix} '
        '${BetaRepairLabCopy.modeLabel(mode)}';
  }

  static BetaRepairLabMode parseBuildRepairMode(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty || normalized == BetaRepairLabMode.none.name) {
      return BetaRepairLabMode.none;
    }
    for (final mode in BetaRepairLabMode.values) {
      if (mode.name == normalized || mode.analyticsValue == normalized) {
        return mode;
      }
    }
    return BetaRepairLabMode.none;
  }

  static Future<void> ensureLoaded() async {
    if (!AppServices.isInitialized) return;
    if (_loaded) return;
    final raw = await AppServices.instance.prefs.readMap(prefsKey);
    _mode = _parseStoredMode(raw?['selectedMode']);
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

  static BetaRepairLabMode _parseStoredMode(Object? raw) {
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
    repairModeOverrideForTest = null;
    if (prefs == null) return;
    await prefs.writeMap(prefsKey, {});
  }
}
