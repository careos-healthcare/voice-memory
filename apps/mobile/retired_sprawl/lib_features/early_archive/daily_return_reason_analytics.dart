import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/early_archive/daily_return_reason_model.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for daily return reason — kind and surface only.
abstract final class DailyReturnReasonAnalytics {
  DailyReturnReasonAnalytics._();

  static const recordTappedEvent = 'daily_return_reason_record_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void recordTapped({
    required DailyReturnReasonKind kind,
    required String surface,
    required int entryCount,
  }) {
    final props = <String, Object>{
      'kind': kind.name,
      'surface': surface,
      'entry_count': entryCount,
    };
    captureForTest?.call(recordTappedEvent, props);
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_DAILY_RETURN event=$recordTappedEvent '
        'kind=${kind.name} surface=$surface entry_count=$entryCount',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}