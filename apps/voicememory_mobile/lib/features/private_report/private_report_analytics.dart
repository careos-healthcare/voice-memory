import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Safe analytics for private report — metadata only, never report body.
abstract final class PrivateReportAnalytics {
  PrivateReportAnalytics._();

  static const openedEvent = 'private_report_opened';
  static const copiedEvent = 'private_report_copied';
  static const sharedEvent = 'private_report_shared';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void opened({
    required String source,
    required int entryCount,
    required bool hasChange,
    required bool hasHelped,
  }) {
    _emit(
      openedEvent,
      source: source,
      entryCount: entryCount,
      hasChange: hasChange,
      hasHelped: hasHelped,
    );
  }

  static void copied({
    required String source,
    required int entryCount,
    required bool hasChange,
    required bool hasHelped,
  }) {
    _emit(
      copiedEvent,
      source: source,
      entryCount: entryCount,
      hasChange: hasChange,
      hasHelped: hasHelped,
    );
  }

  static void shared({
    required String source,
    required int entryCount,
    required bool hasChange,
    required bool hasHelped,
  }) {
    _emit(
      sharedEvent,
      source: source,
      entryCount: entryCount,
      hasChange: hasChange,
      hasHelped: hasHelped,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasChange,
    required bool hasHelped,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_change': hasChange ? 1 : 0,
      'has_helped': hasHelped ? 1 : 0,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasChange: hasChange,
      hasHelped: hasHelped,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRIVATE_REPORT event=$event source=$source '
        'entry_count=$entryCount has_change=$hasChange has_helped=$hasHelped',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
