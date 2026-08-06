import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'what_changed_v2_model.dart';

/// Safe analytics for What Changed v2 — metadata only.
abstract final class WhatChangedV2Analytics {
  WhatChangedV2Analytics._();

  static const seenEvent = 'what_changed_v2_seen';
  static const answeredEvent = 'what_changed_v2_answered';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      answer: null,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void answered({
    required String source,
    required int entryCount,
    required WhatChangedV2Option answer,
    required bool hasConfirmedRepeat,
  }) {
    _emit(
      answeredEvent,
      source: source,
      entryCount: entryCount,
      answer: answer.analyticsValue,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required String? answer,
    required bool hasConfirmedRepeat,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'answer': ?answer,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      answer: answer,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_WHAT_CHANGED_V2 event=$event source=$source '
        'entry_count=$entryCount answer=$answer '
        'has_confirmed_repeat=$hasConfirmedRepeat',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
