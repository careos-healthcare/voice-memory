import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'not_relevant_recovery_copy.dart';
import 'not_relevant_recovery_model.dart';

/// Safe metadata analytics for not-relevant recovery — no journal text.
abstract final class NotRelevantRecoveryAnalytics {
  NotRelevantRecoveryAnalytics._();

  static const seenEvent = 'not_relevant_recovery_seen';
  static const actionTappedEvent = 'not_relevant_recovery_action_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required NotRelevantRecoveryResult result,
  }) {
    _emit(
      seenEvent,
      source: source,
      actionType: null,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      hasFreshReturn: result.hasFreshReturn,
    );
  }

  static void actionTapped({
    required String source,
    required NotRelevantRecoveryActionType actionType,
    required NotRelevantRecoveryResult result,
  }) {
    _emit(
      actionTappedEvent,
      source: source,
      actionType: actionType,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
      hasFreshReturn: result.hasFreshReturn,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required NotRelevantRecoveryActionType? actionType,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool hasFreshReturn,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': entryCount,
      'has_confirmed_repeat': hasConfirmedRepeat ? 1 : 0,
      'has_fresh_return': hasFreshReturn ? 1 : 0,
      if (actionType != null) 'action_type': actionType.analyticsValue,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_NOT_RELEVANT_RECOVERY event=$event source=$source '
        'action_type=${actionType?.analyticsValue ?? 'none'} '
        'entry_count=$entryCount has_confirmed_repeat=$hasConfirmedRepeat '
        'has_fresh_return=$hasFreshReturn',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
