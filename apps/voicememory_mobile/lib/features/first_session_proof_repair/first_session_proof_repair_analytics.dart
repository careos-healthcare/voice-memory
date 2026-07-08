import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'first_session_proof_repair_copy.dart';
import 'first_session_proof_repair_model.dart';

abstract final class FirstSessionProofRepairAnalytics {
  FirstSessionProofRepairAnalytics._();

  static const captureSeenEvent = 'first_session_proof_repair_seen';
  static const captureCtaEvent = 'first_session_proof_repair_cta_tapped';
  static const captureChipEvent = 'first_session_proof_repair_chip_tapped';
  static const proofSeenEvent = 'proof_quality_repair_seen';
  static const proofAnsweredEvent = 'proof_quality_repair_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void captureSeen({required FirstSessionCaptureRepairResult result}) {
    _emitCapture(captureSeenEvent, result: result);
  }

  static void captureCtaTapped({
    required FirstSessionCaptureRepairResult result,
    required FirstSessionProofRepairActionType actionType,
    FirstSessionProofRepairChipId? chipId,
  }) {
    _emitCapture(
      captureCtaEvent,
      result: result,
      actionType: actionType,
      chipId: chipId,
    );
  }

  static void captureChipTapped({
    required FirstSessionCaptureRepairResult result,
    required FirstSessionProofRepairChipId chipId,
  }) {
    _emitCapture(
      captureChipEvent,
      result: result,
      actionType: FirstSessionProofRepairActionType.chipTapped,
      chipId: chipId,
    );
  }

  static void proofSeen({required ProofQualityRepairResult result}) {
    _emitProof(proofSeenEvent, result: result);
  }

  static void proofAnswered({
    required ProofQualityRepairResult result,
    required BetaProofFeedbackType answerType,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'answer_type': answerType.storageValue,
      'confidence_level': result.confidenceLevel.analyticsValue,
    };
    captureForTest?.call(proofAnsweredEvent, props);
    ActivationFunnelAnalytics.track(
      proofAnsweredEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_QUALITY_REPAIR event=$proofAnsweredEvent '
        'source=${result.source} entry_count=${result.entryCount} '
        'answer_type=${answerType.storageValue} '
        'confidence_level=${result.confidenceLevel.analyticsValue}',
      );
    }
  }

  static void _emitCapture(
    String event, {
    required FirstSessionCaptureRepairResult result,
    FirstSessionProofRepairActionType? actionType,
    FirstSessionProofRepairChipId? chipId,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
    };
    if (actionType != null) {
      props['action_type'] = actionType.analyticsValue;
    }
    if (chipId != null) {
      props['chip_id'] = FirstSessionProofRepairCopy.captureChipAnalyticsId(chipId);
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_FIRST_SESSION_PROOF_REPAIR event=$event '
        'source=${result.source} entry_count=${result.entryCount}'
        '${actionType == null ? '' : ' action_type=${actionType.analyticsValue}'}'
        '${chipId == null ? '' : ' chip_id=${FirstSessionProofRepairCopy.captureChipAnalyticsId(chipId)}'}',
      );
    }
  }

  static void _emitProof(String event, {required ProofQualityRepairResult result}) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
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
        'ARCHIVEME_PROOF_QUALITY_REPAIR event=$event source=${result.source} '
        'entry_count=${result.entryCount} '
        'confidence_level=${result.confidenceLevel.analyticsValue}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
