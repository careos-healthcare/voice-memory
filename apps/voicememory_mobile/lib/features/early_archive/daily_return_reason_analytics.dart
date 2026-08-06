import 'package:flutter/foundation.dart';

import 'daily_return_reason_model.dart';

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
      debugPrint(
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
