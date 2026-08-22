import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for private insight share cards — metadata only.
abstract final class ShareCardAnalytics {
  ShareCardAnalytics._();

  static const createdEvent = 'share_card_created';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void created({
    required String source,
    required bool hasChange,
    required int entryCount,
  }) {
    final props = <String, Object>{
      'source': source,
      'has_change': hasChange ? 1 : 0,
      'entry_count': entryCount,
    };
    captureForTest?.call(createdEvent, props);
    ActivationFunnelAnalytics.track(
      createdEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasChange,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_SHARE_CARD event=$createdEvent source=$source '
        'has_change=$hasChange entry_count=$entryCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}