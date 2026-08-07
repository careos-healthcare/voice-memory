import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for contextual privacy reassurance — metadata only.
abstract final class ContextualPrivacyAnalytics {
  ContextualPrivacyAnalytics._();

  static const seenEvent = 'privacy_reassurance_seen';
  static const openedEvent = 'privacy_controls_opened';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void reassuranceSeen({
    required String source,
    required int entryCount,
  }) {
    final props = <String, Object>{'source': source, 'entry_count': entryCount};
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_CONTEXTUAL_PRIVACY event=$seenEvent source=$source '
        'entry_count=$entryCount',
      );
    }
  }

  static void controlsOpened({required String source}) {
    final props = <String, Object>{'source': source};
    captureForTest?.call(openedEvent, props);
    ActivationFunnelAnalytics.track(openedEvent, source: source);
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_CONTEXTUAL_PRIVACY event=$openedEvent source=$source',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
