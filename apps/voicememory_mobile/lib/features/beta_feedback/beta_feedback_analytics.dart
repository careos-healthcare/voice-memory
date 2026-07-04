import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for beta feedback v1 — no note text.
abstract final class BetaFeedbackAnalytics {
  BetaFeedbackAnalytics._();

  static const openedEvent = 'beta_feedback_opened';
  static const submittedEvent = 'beta_feedback_submitted';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void opened({
    required String source,
    required int entryCount,
  }) {
    _emit(
      openedEvent,
      source: source,
      entryCount: entryCount,
    );
  }

  static void submitted({
    required String source,
    required String optionType,
    required int entryCount,
  }) {
    _emit(
      submittedEvent,
      source: source,
      entryCount: entryCount,
      optionType: optionType,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    String? optionType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
    };
    if (optionType != null) props['option_type'] = optionType;

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      answer: optionType,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_FEEDBACK event=$event source=$source '
        'entry_count=$entryCount '
        '${optionType != null ? 'option_type=$optionType' : ''}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
