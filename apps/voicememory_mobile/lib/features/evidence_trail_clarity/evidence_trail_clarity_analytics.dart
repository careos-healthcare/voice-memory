import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'evidence_trail_clarity_model.dart';

abstract final class EvidenceTrailClarityAnalytics {
  EvidenceTrailClarityAnalytics._();

  static const seenEvent = 'evidence_trail_clarity_seen';
  static const ctaTappedEvent = 'evidence_trail_clarity_cta_tapped';
  static const feedbackSelectedEvent =
      'evidence_trail_clarity_feedback_selected';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required EvidenceTrailClarityResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({required EvidenceTrailClarityResult result}) {
    _emit(ctaTappedEvent, result: result);
  }

  static void feedbackSelected({
    required EvidenceTrailClarityResult result,
    required EvidenceTrailClarityFeedbackOption feedback,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'active_repair_mode': result.activeRepairMode,
      'feedback': feedback.analyticsValue,
      'has_useful_proof': result.hasUsefulProof,
      'confidence_level': result.confidenceLevel.analyticsValue,
    };
    captureForTest?.call(feedbackSelectedEvent, props);
    ActivationFunnelAnalytics.track(
      feedbackSelectedEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_EVIDENCE_TRAIL_CLARITY event=$feedbackSelectedEvent '
        'source=${result.source} entry_count=${result.entryCount} '
        'feedback=${feedback.analyticsValue} '
        'has_useful_proof=${result.hasUsefulProof} '
        'confidence_level=${result.confidenceLevel.analyticsValue} '
        'active_repair_mode=${result.activeRepairMode}',
      );
    }
  }

  static void _emit(
    String event, {
    required EvidenceTrailClarityResult result,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'active_repair_mode': result.activeRepairMode,
      'has_useful_proof': result.hasUsefulProof,
      'confidence_level': result.confidenceLevel.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_EVIDENCE_TRAIL_CLARITY event=$event source=${result.source} '
        'entry_count=${result.entryCount} '
        'has_useful_proof=${result.hasUsefulProof} '
        'confidence_level=${result.confidenceLevel.analyticsValue} '
        'active_repair_mode=${result.activeRepairMode}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
