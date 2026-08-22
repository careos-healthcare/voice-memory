import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/first_save_lift/first_save_lift_copy.dart';
import 'package:archiveme_mobile/features/first_save_lift/first_save_lift_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

abstract final class FirstSaveLiftAnalytics {
  FirstSaveLiftAnalytics._();

  static const seenEvent = 'first_save_lift_seen';
  static const ctaTappedEvent = 'first_save_lift_cta_tapped';
  static const exampleTappedEvent = 'first_save_lift_example_tapped';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required FirstSaveLiftResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({
    required FirstSaveLiftResult result,
    required FirstSaveLiftActionType actionType,
  }) {
    _emit(ctaTappedEvent, result: result, actionType: actionType);
  }

  static void exampleTapped({
    required FirstSaveLiftResult result,
    required FirstSaveLiftExampleId exampleId,
  }) {
    _emit(
      exampleTappedEvent,
      result: result,
      actionType: FirstSaveLiftActionType.exampleTapped,
      exampleId: FirstSaveLiftCopy.exampleAnalyticsId(exampleId),
    );
  }

  static void _emit(
    String event, {
    required FirstSaveLiftResult result,
    FirstSaveLiftActionType? actionType,
    String? exampleId,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
    };
    if (actionType != null) {
      props['action_type'] = actionType.analyticsValue;
    }
    if (exampleId != null) {
      props['example_id'] = exampleId;
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_FIRST_SAVE_LIFT event=$event source=${result.source} '
        'entry_count=${result.entryCount}'
        '${actionType == null ? '' : ' action_type=${actionType.analyticsValue}'}'
        '${exampleId == null ? '' : ' example_id=$exampleId'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}