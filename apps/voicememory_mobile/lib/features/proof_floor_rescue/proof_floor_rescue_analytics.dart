import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'proof_floor_rescue_copy.dart';
import 'proof_floor_rescue_model.dart';

abstract final class ProofFloorRescueAnalytics {
  ProofFloorRescueAnalytics._();

  static const seenEvent = 'proof_floor_rescue_seen';
  static const ctaTappedEvent = 'proof_floor_rescue_cta_tapped';
  static const feedbackAnsweredEvent = 'proof_floor_rescue_feedback_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required ProofFloorRescueResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({
    required ProofFloorRescueResult result,
    required ProofFloorRescueCtaType ctaType,
  }) {
    _emit(
      ctaTappedEvent,
      result: result,
      ctaType: ctaType,
    );
  }

  static void feedbackAnswered({
    required ProofFloorRescueResult result,
    required BetaProofFeedbackType answerType,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'rescue_state': result.state.analyticsValue,
      'confidence_level': result.confidenceLevel.analyticsValue,
      'answer_type': answerType.storageValue,
    };
    captureForTest?.call(feedbackAnsweredEvent, props);
    ActivationFunnelAnalytics.track(
      feedbackAnsweredEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_FLOOR_RESCUE event=$feedbackAnsweredEvent '
        'source=${result.source} entry_count=${result.entryCount} '
        'rescue_state=${result.state.analyticsValue} '
        'confidence_level=${result.confidenceLevel.analyticsValue} '
        'answer_type=${answerType.storageValue}',
      );
    }
  }

  static void _emit(
    String event, {
    required ProofFloorRescueResult result,
    ProofFloorRescueCtaType? ctaType,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'rescue_state': result.state.analyticsValue,
      'confidence_level': result.confidenceLevel.analyticsValue,
    };
    if (ctaType != null) {
      props['answer_type'] = ctaType.analyticsValue;
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_FLOOR_RESCUE event=$event source=${result.source} '
        'entry_count=${result.entryCount} '
        'rescue_state=${result.state.analyticsValue} '
        'confidence_level=${result.confidenceLevel.analyticsValue}'
        '${ctaType == null ? '' : ' answer_type=${ctaType.analyticsValue}'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
