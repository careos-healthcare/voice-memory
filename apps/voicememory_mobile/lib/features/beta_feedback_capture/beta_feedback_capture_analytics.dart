import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'beta_feedback_capture_model.dart';

/// Metadata-only analytics for beta feedback capture cards.
abstract final class BetaFeedbackCaptureAnalytics {
  BetaFeedbackCaptureAnalytics._();

  static const seenEvent = 'beta_feedback_capture_seen';
  static const answeredEvent = 'beta_feedback_capture_answered';
  static const dismissedEvent = 'beta_feedback_capture_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required BetaFeedbackCaptureResult result}) {
    _emit(seenEvent, result: result);
  }

  static void answered({
    required BetaFeedbackCaptureResult result,
    required String answerId,
  }) {
    _emit(
      answeredEvent,
      result: result,
      answerId: answerId,
    );
  }

  static void dismissed({required BetaFeedbackCaptureResult result}) {
    _emit(dismissedEvent, result: result);
  }

  static void _emit(
    String event, {
    required BetaFeedbackCaptureResult result,
    String? answerId,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'moment': result.moment.analyticsValue,
      'entry_count': result.entryCount,
      'has_useful_proof': result.hasUsefulProof ? 1 : 0,
      'has_paywall_seen': result.hasPaywallSeen ? 1 : 0,
      'has_purchase_cta': result.hasPurchaseCtaTapped ? 1 : 0,
    };
    if (answerId != null) {
      props['answer_id'] = answerId;
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_FEEDBACK_CAPTURE event=$event source=${result.source} '
        'moment=${result.moment.analyticsValue} entry_count=${result.entryCount} '
        'has_useful_proof=${result.hasUsefulProof} '
        'has_paywall_seen=${result.hasPaywallSeen} '
        'has_purchase_cta=${result.hasPurchaseCtaTapped}'
        '${answerId == null ? '' : ' answer_id=$answerId'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
