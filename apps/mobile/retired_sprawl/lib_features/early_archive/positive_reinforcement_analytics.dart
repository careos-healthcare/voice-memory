import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for positive reinforcement — metadata only.
abstract final class PositiveReinforcementAnalytics {
  PositiveReinforcementAnalytics._();

  static const seenEvent = 'positive_reinforcement_seen';
  static const recordTappedEvent = 'positive_reinforcement_record_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String surface,
    required int entryCount,
    required bool helpfulPatternSeen,
  }) {
    _emit(
      seenEvent,
      surface: surface,
      entryCount: entryCount,
      helpfulPatternSeen: helpfulPatternSeen,
    );
  }

  static void recordTapped({
    required String surface,
    required int entryCount,
    required bool helpfulPatternRecorded,
  }) {
    _emit(
      recordTappedEvent,
      surface: surface,
      entryCount: entryCount,
      helpfulPatternSeen: true,
      helpfulPatternRecorded: helpfulPatternRecorded,
    );
  }

  static void _emit(
    String event, {
    required String surface,
    required int entryCount,
    required bool helpfulPatternSeen,
    bool? helpfulPatternRecorded,
  }) {
    final props = <String, Object>{
      'surface': surface,
      'entry_count': entryCount,
      'helpful_pattern_seen': helpfulPatternSeen,
      'helpful_pattern_recorded': ?helpfulPatternRecorded,
    };
    captureForTest?.call(event, props);
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_POSITIVE_REINFORCEMENT event=$event surface=$surface '
        'entry_count=$entryCount helpful_pattern_seen=$helpfulPatternSeen '
        'helpful_pattern_recorded=$helpfulPatternRecorded',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}