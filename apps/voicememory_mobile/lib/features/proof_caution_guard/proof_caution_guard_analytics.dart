import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'proof_caution_guard_model.dart';

/// Metadata-only analytics for proof caution rollback guard.
abstract final class ProofCautionGuardAnalytics {
  ProofCautionGuardAnalytics._();

  static const appliedEvent = 'proof_caution_guard_applied';
  static const blockedEvent = 'proof_caution_guard_blocked';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void applied({
    required int entryCount,
    required String source,
    required ProofConfidenceLevel originalLevel,
    required ProofConfidenceLevel adjustedLevel,
    required ProofCautionGuardUpgradeReason reason,
  }) {
    _emit(
      appliedEvent,
      entryCount: entryCount,
      source: source,
      originalLevel: originalLevel,
      adjustedLevel: adjustedLevel,
      reason: reason.analyticsValue,
    );
  }

  static void blocked({
    required int entryCount,
    required String source,
    required ProofConfidenceLevel originalLevel,
    required ProofCautionGuardBlockedReason blockedReason,
  }) {
    _emit(
      blockedEvent,
      entryCount: entryCount,
      source: source,
      originalLevel: originalLevel,
      blockedReason: blockedReason.analyticsValue,
    );
  }

  static void _emit(
    String event, {
    required int entryCount,
    required String source,
    required ProofConfidenceLevel originalLevel,
    ProofConfidenceLevel? adjustedLevel,
    String? reason,
    String? blockedReason,
  }) {
    final properties = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'original_level': originalLevel.analyticsValue,
      if (adjustedLevel != null) 'adjusted_level': adjustedLevel.analyticsValue,
      if (reason != null) 'reason': reason,
      if (blockedReason != null) 'blocked_reason': blockedReason,
    };

    captureForTest?.call(event, properties);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_CAUTION_GUARD event=$event source=$source '
        'entry_count=$entryCount original_level=${originalLevel.analyticsValue} '
        'adjusted_level=${adjustedLevel?.analyticsValue ?? 'none'} '
        'reason=${reason ?? 'none'} blocked_reason=${blockedReason ?? 'none'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
