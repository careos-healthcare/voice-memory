import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for Return Day Flow v2 — metadata only, no phrase text.
abstract final class ReturnDayFlowAnalytics {
  ReturnDayFlowAnalytics._();

  static const seenEvent = 'return_day_flow_seen';
  static const answeredEvent = 'return_day_flow_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool hasGroundedPhrase,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      hasGroundedPhrase: hasGroundedPhrase,
    );
  }

  static void answered({
    required String source,
    required int entryCount,
    required String answer,
    required bool hasGroundedPhrase,
  }) {
    _emit(
      answeredEvent,
      source: source,
      entryCount: entryCount,
      hasGroundedPhrase: hasGroundedPhrase,
      answer: answer,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasGroundedPhrase,
    String? answer,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_grounded_phrase': hasGroundedPhrase ? 1 : 0,
    };
    if (answer != null) props['answer'] = answer;

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      answer: answer,
      hasPhrase: hasGroundedPhrase,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_RETURN_DAY_FLOW event=$event source=$source '
        'entry_count=$entryCount has_grounded_phrase=$hasGroundedPhrase '
        '${answer != null ? 'answer=$answer' : ''}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
