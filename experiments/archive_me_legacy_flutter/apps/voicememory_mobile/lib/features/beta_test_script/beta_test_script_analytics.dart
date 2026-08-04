import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the beta tester script.
abstract final class BetaTestScriptAnalytics {
  BetaTestScriptAnalytics._();

  static const openedEvent = 'beta_test_script_opened';
  static const stepSeenEvent = 'beta_test_step_seen';
  static const progressResetEvent = 'beta_test_progress_reset';
  static const feedbackCtaTappedEvent = 'beta_test_feedback_cta_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void opened({required String source, required int entryCount}) {
    _emit(openedEvent, source: source, entryCount: entryCount);
  }

  static void stepSeen({
    required String source,
    required String step,
    required int entryCount,
  }) {
    _emit(stepSeenEvent, source: source, step: step, entryCount: entryCount);
  }

  static void progressReset({required String source}) {
    _emit(progressResetEvent, source: source);
  }

  static void feedbackCtaTapped({
    required String source,
    required int entryCount,
  }) {
    _emit(feedbackCtaTappedEvent, source: source, entryCount: entryCount);
  }

  static void _emit(
    String event, {
    required String source,
    int? entryCount,
    String? step,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': ?entryCount,
      'step': ?step,
    };

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      step: step,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_TEST_SCRIPT event=$event source=$source '
        '${entryCount != null ? 'entry_count=$entryCount ' : ''}'
        '${step != null ? 'step=$step' : ''}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
