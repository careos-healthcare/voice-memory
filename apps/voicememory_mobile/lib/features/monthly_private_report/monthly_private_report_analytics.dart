import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the monthly private report preview.
abstract final class MonthlyPrivateReportAnalytics {
  MonthlyPrivateReportAnalytics._();

  static const seenEvent = 'monthly_private_report_preview_seen';
  static const ctaTappedEvent = 'monthly_private_report_preview_cta_tapped';
  static const dismissedEvent = 'monthly_private_report_preview_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasChangeSignal,
    required bool hasHelpedSignal,
    required bool hasQuietSignal,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasChangeSignal: hasChangeSignal,
      hasHelpedSignal: hasHelpedSignal,
      hasQuietSignal: hasQuietSignal,
    );
  }

  static void ctaTapped({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasChangeSignal,
    required bool hasHelpedSignal,
    required bool hasQuietSignal,
    required String actionType,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasChangeSignal: hasChangeSignal,
      hasHelpedSignal: hasHelpedSignal,
      hasQuietSignal: hasQuietSignal,
      actionType: actionType,
    );
  }

  static void dismissed({
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasChangeSignal,
    required bool hasHelpedSignal,
    required bool hasQuietSignal,
  }) {
    _emit(
      dismissedEvent,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasChangeSignal: hasChangeSignal,
      hasHelpedSignal: hasHelpedSignal,
      hasQuietSignal: hasQuietSignal,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasChangeSignal,
    required bool hasHelpedSignal,
    required bool hasQuietSignal,
    String? actionType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'has_change_signal': hasChangeSignal ? 1 : 0,
      'has_helped_signal': hasHelpedSignal ? 1 : 0,
      'has_quiet_signal': hasQuietSignal ? 1 : 0,
      if (actionType != null) 'action_type': actionType,
    };

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_MONTHLY_PRIVATE_REPORT event=$event source=$source '
        'entry_count=$entryCount has_confirmed_repeat=${props['has_confirmed_repeat']} '
        'has_change_signal=${props['has_change_signal']} '
        'has_helped_signal=${props['has_helped_signal']} '
        'has_quiet_signal=${props['has_quiet_signal']}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
