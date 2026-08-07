import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'what_to_notice_next_model.dart';

/// Safe metadata analytics for observation guidance — no journal text.
abstract final class WhatToNoticeNextAnalytics {
  WhatToNoticeNextAnalytics._();

  static const seenEvent = 'what_to_notice_next_seen';
  static const promptTappedEvent = 'what_to_notice_next_prompt_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required WhatToNoticeNextResult result}) {
    _emit(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
      promptType: null,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      hasTimeline: result.hasTimeline,
    );
  }

  static void promptTapped({
    required WhatToNoticeNextResult result,
    required WhatToNoticeNextPromptType promptType,
  }) {
    _emit(
      promptTappedEvent,
      source: result.source,
      entryCount: result.entryCount,
      promptType: promptType,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      hasTimeline: result.hasTimeline,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required WhatToNoticeNextPromptType? promptType,
    required bool hasConfirmedRepeat,
    required bool hasTimeline,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'has_timeline': hasTimeline ? 1 : 0,
      if (promptType != null) 'prompt_type': promptType.analyticsValue,
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
        'ARCHIVEME_WHAT_TO_NOTICE_NEXT event=$event source=$source '
        'entry_count=$entryCount prompt_type=${promptType?.analyticsValue ?? 'none'} '
        'has_confirmed_repeat=$hasConfirmedRepeat has_timeline=$hasTimeline',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
