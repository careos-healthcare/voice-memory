import 'package:flutter/foundation.dart';

import '../../services/app_services.dart';

/// Persists proof milestones required before Pro bridge or paywall may show.
abstract final class DelayedPaywallProofStore {
  DelayedPaywallProofStore._();

  static const prefsKey = 'delayedPaywallProof_v1';

  static bool _loaded = false;
  static bool _hasSeenFirstRepeat = false;
  static bool _hasOpenedEvidenceTrail = false;

  /// Widget tests bypass the gate unless a file opts out explicitly.
  @visibleForTesting
  static bool bypassGateForTest = false;

  static bool get hasSeenFirstRepeat => _hasSeenFirstRepeat;
  static bool get hasOpenedEvidenceTrail => _hasOpenedEvidenceTrail;

  static bool get passesGate =>
      bypassGateForTest ||
      (_hasSeenFirstRepeat && _hasOpenedEvidenceTrail);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    final raw = await AppServices.instance.prefs.readMap(prefsKey);
    _hasSeenFirstRepeat = raw?['hasSeenFirstRepeat'] == true;
    _hasOpenedEvidenceTrail = raw?['hasOpenedEvidenceTrail'] == true;
    _loaded = true;
  }

  static Future<void> markFirstRepeatSeen() async {
    if (_hasSeenFirstRepeat) return;
    _hasSeenFirstRepeat = true;
    _loaded = true;
    await _persist();
  }

  static Future<void> markEvidenceTrailOpened() async {
    if (_hasOpenedEvidenceTrail) return;
    _hasOpenedEvidenceTrail = true;
    _loaded = true;
    await _persist();
  }

  static Future<void> _persist() async {
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {
      'hasSeenFirstRepeat': _hasSeenFirstRepeat,
      'hasOpenedEvidenceTrail': _hasOpenedEvidenceTrail,
    });
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    _loaded = false;
    _hasSeenFirstRepeat = false;
    _hasOpenedEvidenceTrail = false;
    bypassGateForTest = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }

  @visibleForTesting
  static void seedForTest({
    bool hasSeenFirstRepeat = false,
    bool hasOpenedEvidenceTrail = false,
  }) {
    _loaded = true;
    _hasSeenFirstRepeat = hasSeenFirstRepeat;
    _hasOpenedEvidenceTrail = hasOpenedEvidenceTrail;
  }
}
