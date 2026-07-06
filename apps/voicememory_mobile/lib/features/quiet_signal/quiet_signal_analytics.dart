import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for quiet / not-seen-recently moments.
abstract final class QuietSignalAnalytics {
  QuietSignalAnalytics._();

  static const seenEvent = 'quiet_signal_seen';
  static const ctaTappedEvent = 'quiet_signal_cta_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required int entryCount,
    required int daysSinceSeen,
  }) {
    _emit(
      seenEvent,
      source: source,
      entryCount: entryCount,
      daysSinceSeen: daysSinceSeen,
    );
  }

  static void ctaTapped({
    required String source,
    required int entryCount,
    required String actionType,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      entryCount: entryCount,
      actionType: actionType,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required int entryCount,
    int? daysSinceSeen,
    String? actionType,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      if (daysSinceSeen != null) 'days_since_seen': daysSinceSeen,
      if (actionType != null) 'action_type': actionType,
    };

    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      daysSinceSeen: daysSinceSeen,
      actionType: actionType,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_QUIET_SIGNAL event=$event source=$source '
        'entry_count=$entryCount '
        '${daysSinceSeen != null ? 'days_since_seen=$daysSinceSeen ' : ''}'
        '${actionType != null ? 'action_type=$actionType' : ''}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
