import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../evidence_anchors/evidence_anchor_model.dart';
import 'anchor_calibration_model.dart';

/// Metadata-only analytics for anchor calibration corrections.
abstract final class AnchorCalibrationAnalytics {
  AnchorCalibrationAnalytics._();

  static const appliedEvent = 'anchor_calibration_applied';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void applied({
    required int entryCount,
    required String source,
    required BetaProofFeedbackType? feedbackType,
    required EvidenceAnchorType? oldAnchorType,
    required EvidenceAnchorType? newAnchorType,
    required AnchorCalibrationAction calibrationAction,
  }) {
    final properties = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      if (feedbackType != null) 'feedback_type': feedbackType.analyticsValue,
      if (oldAnchorType != null)
        'old_anchor_type': oldAnchorType.analyticsValue,
      if (newAnchorType != null)
        'new_anchor_type': newAnchorType.analyticsValue,
      'calibration_action': calibrationAction.analyticsValue,
    };

    captureForTest?.call(appliedEvent, properties);
    ActivationFunnelAnalytics.track(
      appliedEvent,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_ANCHOR_CALIBRATION event=$appliedEvent source=$source '
        'entry_count=$entryCount feedback_type=${feedbackType?.analyticsValue ?? 'none'} '
        'old_anchor_type=${oldAnchorType?.analyticsValue ?? 'none'} '
        'new_anchor_type=${newAnchorType?.analyticsValue ?? 'none'} '
        'calibration_action=${calibrationAction.analyticsValue}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
