import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for Positive Pattern — surface and entry count only.
abstract final class PositivePatternAnalytics {
  PositivePatternAnalytics._();

  static const recordAgainTappedEvent = 'positive_pattern_record_again';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void recordAgainTapped({
    required String surface,
    required int entryCount,
  }) {
    final props = <String, Object>{
      'surface': surface,
      'entry_count': entryCount,
    };
    captureForTest?.call(recordAgainTappedEvent, props);
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_POSITIVE_PATTERN event=$recordAgainTappedEvent '
        'surface=$surface entry_count=$entryCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}