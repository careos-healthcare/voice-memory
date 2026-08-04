import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'beta_proof_feedback_model.dart';

/// Safe metadata analytics for beta proof feedback — no journal text.
abstract final class BetaProofFeedbackAnalytics {
  BetaProofFeedbackAnalytics._();

  static const seenEvent = 'beta_proof_feedback_seen';
  static const answeredEvent = 'beta_proof_feedback_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required BetaProofFeedbackSurface surface,
    required int entryCount,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: surface,
      feedbackType: null,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void answered({
    required String source,
    required BetaProofFeedbackSurface surface,
    required BetaProofFeedbackType feedbackType,
    required int entryCount,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      answeredEvent,
      source: source,
      surface: surface,
      feedbackType: feedbackType,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required BetaProofFeedbackSurface surface,
    required BetaProofFeedbackType? feedbackType,
    required int entryCount,
    required bool hasConfirmedRepeat,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface.analyticsValue,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      if (feedbackType != null) 'feedback_type': feedbackType.analyticsValue,
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
        'ARCHIVEME_BETA_PROOF_FEEDBACK event=$event source=$source '
        'surface=${surface.analyticsValue} feedback_type='
        '${feedbackType?.analyticsValue ?? 'none'} entry_count=$entryCount '
        'has_confirmed_repeat=$hasConfirmedRepeat',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
