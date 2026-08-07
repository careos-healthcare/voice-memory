import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for purchase-confidence surfaces — no journal text.
abstract final class PurchaseConfidenceAnalytics {
  PurchaseConfidenceAnalytics._();

  static const seenEvent = 'purchase_confidence_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required String surface,
    int? entryCount,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'entry_count': ?entryCount,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: entryCount,
      surfaceType: surface,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PURCHASE_CONFIDENCE event=$seenEvent source=$source '
        'surface=$surface entry_count=${entryCount ?? 'none'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
