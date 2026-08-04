import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'proof_quality_response_model.dart';

/// Safe metadata analytics for proof quality response — no journal text.
abstract final class ProofQualityResponseAnalytics {
  ProofQualityResponseAnalytics._();

  static const seenEvent = 'proof_quality_response_seen';
  static const answeredEvent = 'proof_quality_response_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required ProofQualityResponseResult result,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: result.surface,
      feedbackState: result.feedbackState,
      answerType: null,
      entryCount: result.entryCount,
      hasSafeAnchor: result.hasSafeAnchor,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
  }

  static void answered({
    required String source,
    required ProofQualityResponseResult result,
    required ProofQualityResponseAnswerType answerType,
  }) {
    _emit(
      answeredEvent,
      source: source,
      surface: result.surface,
      feedbackState: result.feedbackState,
      answerType: answerType,
      entryCount: result.entryCount,
      hasSafeAnchor: result.hasSafeAnchor,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required ProofQualityResponseSurface surface,
    required ProofQualityFeedbackState feedbackState,
    required ProofQualityResponseAnswerType? answerType,
    required int entryCount,
    required bool hasSafeAnchor,
    required bool hasConfirmedRepeat,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface.storageValue,
      'feedback_state': feedbackState.analyticsValue,
      'entry_count': entryCount,
      'has_safe_anchor': hasSafeAnchor ? 1 : 0,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      if (answerType != null) 'answer_type': answerType.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PROOF_QUALITY_RESPONSE event=$event source=$source '
        'surface=${surface.storageValue} feedback_state=${feedbackState.analyticsValue} '
        'answer_type=${answerType?.analyticsValue ?? 'none'} '
        'entry_count=$entryCount has_safe_anchor=$hasSafeAnchor '
        'has_confirmed_repeat=$hasConfirmedRepeat',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
