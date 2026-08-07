import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'first_session_lift_copy.dart';
import 'first_session_lift_model.dart';

abstract final class FirstSessionLiftAnalytics {
  FirstSessionLiftAnalytics._();

  static const seenEvent = 'first_session_lift_seen';
  static const ctaTappedEvent = 'first_session_lift_cta_tapped';
  static const chipTappedEvent = 'first_session_lift_chip_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required FirstSessionLiftResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({
    required FirstSessionLiftResult result,
    required FirstSessionLiftActionType actionType,
  }) {
    _emit(ctaTappedEvent, result: result, actionType: actionType);
  }

  static void chipTapped({
    required FirstSessionLiftResult result,
    required FirstSessionLiftChipId chipId,
  }) {
    _emit(
      chipTappedEvent,
      result: result,
      actionType: FirstSessionLiftActionType.chipTapped,
      chipId: FirstSessionLiftCopy.chipAnalyticsId(chipId),
    );
  }

  static void _emit(
    String event, {
    required FirstSessionLiftResult result,
    FirstSessionLiftActionType? actionType,
    String? chipId,
  }) {
    final props = <String, Object>{'source': result.source};
    if (actionType != null) {
      props['action_type'] = actionType.analyticsValue;
    }
    if (chipId != null) {
      props['chip_id'] = chipId;
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_FIRST_SESSION_LIFT event=$event source=${result.source}'
        '${actionType == null ? '' : ' action_type=${actionType.analyticsValue}'}'
        '${chipId == null ? '' : ' chip_id=$chipId'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
