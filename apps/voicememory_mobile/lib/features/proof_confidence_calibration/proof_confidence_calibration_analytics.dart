import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'proof_confidence_calibration_model.dart';

/// Metadata-only analytics for proof confidence calibration.
abstract final class ProofConfidenceCalibrationAnalytics {
  ProofConfidenceCalibrationAnalytics._();

  static const calibratedEvent = 'proof_confidence_calibrated';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void calibrated({
    required ProofConfidenceCalibrationResult result,
  }) {
    if (!result.shouldCalibrate) return;

    final props = <String, Object>{
      'entry_count': result.entryCount,
      'source': result.source,
      'confidence_level': result.level.analyticsValue,
      'has_safe_anchor': result.hasSafeAnchor ? 1 : 0,
      'has_match_quality': result.hasMatchQuality ? 1 : 0,
      'has_correction': result.hasCorrection ? 1 : 0,
      'has_fresh_return': result.hasFreshReturn ? 1 : 0,
    };
    captureForTest?.call(calibratedEvent, props);
    ActivationFunnelAnalytics.track(
      calibratedEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_CONFIDENCE event=$calibratedEvent source=${result.source} '
        'entry_count=${result.entryCount} confidence_level=${result.level.analyticsValue} '
        'has_safe_anchor=${result.hasSafeAnchor} has_match_quality=${result.hasMatchQuality} '
        'has_correction=${result.hasCorrection} has_fresh_return=${result.hasFreshReturn}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
