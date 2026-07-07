import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'return_after_proof_model.dart';

/// Metadata-only analytics for return-after-proof prompts.
abstract final class ReturnAfterProofAnalytics {
  ReturnAfterProofAnalytics._();

  static const seenEvent = 'return_after_proof_seen';
  static const promptTappedEvent = 'return_after_proof_prompt_tapped';
  static const dismissedTodayEvent = 'return_after_proof_dismissed_today';
  static const strengthenedSeenEvent = 'return_after_proof_strengthened_seen';
  static const strengthenedCtaTappedEvent =
      'return_after_proof_strengthened_cta_tapped';
  static const strengthenedDismissedEvent =
      'return_after_proof_strengthened_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required ReturnAfterProofResult result,
  }) {
    _emit(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
      promptType: null,
      hasTimelineProof: result.hasTimelineProof,
      hasFirstProof: result.hasFirstProof,
    );
  }

  static void promptTapped({
    required ReturnAfterProofResult result,
    required ReturnAfterProofPromptType promptType,
  }) {
    _emit(
      promptTappedEvent,
      source: result.source,
      entryCount: result.entryCount,
      promptType: promptType,
      hasTimelineProof: result.hasTimelineProof,
      hasFirstProof: result.hasFirstProof,
    );
  }

  static void strengthenedSeen({
    required ReturnAfterProofStrengthenedResult result,
  }) {
    _emitStrengthened(strengthenedSeenEvent, result: result);
  }

  static void strengthenedCtaTapped({
    required ReturnAfterProofStrengthenedResult result,
  }) {
    _emitStrengthened(strengthenedCtaTappedEvent, result: result);
  }

  static void strengthenedDismissed({
    required ReturnAfterProofStrengthenedResult result,
  }) {
    _emitStrengthened(strengthenedDismissedEvent, result: result);
  }

  static void dismissedToday({
    required ReturnAfterProofResult result,
  }) {
    _emit(
      dismissedTodayEvent,
      source: result.source,
      entryCount: result.entryCount,
      promptType: ReturnAfterProofPromptType.notToday,
      hasTimelineProof: result.hasTimelineProof,
      hasFirstProof: result.hasFirstProof,
    );
  }

  static void _emitStrengthened(
    String event, {
    required ReturnAfterProofStrengthenedResult result,
  }) {
    final props = <String, Object>{
      'entry_count': result.entryCount,
      'source': result.source,
      'target_type': result.targetType.analyticsValue,
      'confidence_level': result.confidenceLevel.analyticsValue,
      'has_anchor': result.hasAnchor ? 1 : 0,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_RETURN_AFTER_PROOF event=$event source=${result.source} '
        'entry_count=${result.entryCount} target_type=${result.targetType.analyticsValue} '
        'confidence_level=${result.confidenceLevel.analyticsValue} '
        'has_anchor=${result.hasAnchor}',
      );
    }
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required ReturnAfterProofPromptType? promptType,
    required bool hasTimelineProof,
    required bool hasFirstProof,
  }) {
    final props = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'has_timeline_proof': hasTimelineProof ? 1 : 0,
      'has_first_proof': hasFirstProof ? 1 : 0,
      if (promptType != null) 'prompt_type': promptType.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasTimelineProof,
      hasFirstProof: hasFirstProof,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_RETURN_AFTER_PROOF event=$event source=$source '
        'entry_count=$entryCount prompt_type=${promptType?.analyticsValue} '
        'has_timeline_proof=$hasTimelineProof has_first_proof=$hasFirstProof',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
