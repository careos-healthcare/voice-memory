import 'package:flutter/foundation.dart';

import 'confirmed_repeat_beta_feedback_models.dart';

/// Safe analytics for confirmed-repeat beta feedback — metadata only.
abstract final class ConfirmedRepeatBetaFeedbackAnalytics {
  ConfirmedRepeatBetaFeedbackAnalytics._();

  static const answerEvent = 'confirmed_repeat_beta_feedback';
  static const dismissedEvent = 'confirmed_repeat_beta_feedback_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void recordAnswer({
    required String surface,
    required int entryCount,
    required ConfirmedRepeatBetaFeedbackChoice answer,
    ConfirmedRepeatBetaFeedbackReason? reason,
  }) {
    _emit(
      answerEvent,
      surface: surface,
      entryCount: entryCount,
      answer: answer.analyticsAnswer,
      reason: reason?.analyticsReason,
    );
  }

  static void recordDismissed({
    required String surface,
    required int entryCount,
  }) {
    _emit(
      dismissedEvent,
      surface: surface,
      entryCount: entryCount,
    );
  }

  static void _emit(
    String event, {
    required String surface,
    required int entryCount,
    String? answer,
    String? reason,
  }) {
    final props = <String, Object>{
      'surface': surface,
      'entry_count': entryCount,
      if (answer != null) 'answer': answer,
      if (reason != null) 'reason': reason,
    };
    captureForTest?.call(event, props);
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_CONFIRMED_REPEAT_BETA event=$event surface=$surface '
        'entry_count=$entryCount answer=$answer reason=$reason',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
