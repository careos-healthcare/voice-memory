import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the pattern review inbox.
abstract final class PatternReviewInboxAnalytics {
  PatternReviewInboxAnalytics._();

  static const seenEvent = 'pattern_review_inbox_seen';
  static const itemTappedEvent = 'pattern_review_item_tapped';
  static const itemCompletedEvent = 'pattern_review_item_completed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required int itemCount,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      itemCount: itemCount,
    );
  }

  static void itemTapped({
    required String source,
    required int entryCount,
    required String itemType,
  }) {
    _emit(
      itemTappedEvent,
      source: source,
      entryCount: entryCount,
      itemType: itemType,
    );
  }

  static void itemCompleted({
    required String source,
    required int entryCount,
    required String itemType,
    required String resultType,
  }) {
    _emit(
      itemCompletedEvent,
      source: source,
      entryCount: entryCount,
      itemType: itemType,
      resultType: resultType,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    int? itemCount,
    String? itemType,
    String? resultType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      if (itemCount != null) 'item_count': itemCount,
      if (itemType != null) 'item_type': itemType,
      if (resultType != null) 'result_type': resultType,
    };

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      itemCount: itemCount,
      itemType: itemType,
      resultType: resultType,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PATTERN_REVIEW_INBOX event=$event source=$source '
        'entry_count=$entryCount '
        '${itemCount != null ? 'item_count=$itemCount ' : ''}'
        '${itemType != null ? 'item_type=$itemType ' : ''}'
        '${resultType != null ? 'result_type=$resultType' : ''}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
