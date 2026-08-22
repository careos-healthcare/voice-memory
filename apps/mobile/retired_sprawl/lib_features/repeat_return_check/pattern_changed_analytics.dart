import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/repeat_return_check/pattern_changed_engine.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for pattern-changed wins — metadata only.
abstract final class PatternChangedAnalytics {
  PatternChangedAnalytics._();

  static const seenEvent = 'pattern_changed_seen';
  static const dismissEvent = 'pattern_changed_dismissed';
  static const recordTappedEvent = 'pattern_changed_record_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String surface,
    required int entryCount,
    required PatternChangedType changeType,
  }) {
    _emit(
      seenEvent,
      surface: surface,
      entryCount: entryCount,
      changeType: changeType,
    );
  }

  static void dismissed({
    required String surface,
    required int entryCount,
    required PatternChangedType changeType,
  }) {
    _emit(
      dismissEvent,
      surface: surface,
      entryCount: entryCount,
      changeType: changeType,
    );
  }

  static void recordTapped({
    required String surface,
    required int entryCount,
    required PatternChangedType changeType,
  }) {
    _emit(
      recordTappedEvent,
      surface: surface,
      entryCount: entryCount,
      changeType: changeType,
    );
  }

  static void _emit(
    String event, {
    required String surface,
    required int entryCount,
    required PatternChangedType changeType,
  }) {
    final props = <String, Object>{
      'surface': surface,
      'entry_count': entryCount,
      'change_type': changeType.analyticsValue,
    };
    captureForTest?.call(event, props);
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PATTERN_CHANGED event=$event surface=$surface '
        'entry_count=$entryCount change_type=${changeType.analyticsValue}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}