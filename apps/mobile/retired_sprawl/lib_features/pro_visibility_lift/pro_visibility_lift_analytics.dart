import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_copy.dart';
import 'package:archiveme_mobile/features/pro_visibility_lift/pro_visibility_lift_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

abstract final class ProVisibilityLiftAnalytics {
  ProVisibilityLiftAnalytics._();

  static const seenEvent = 'pro_visibility_lift_seen';
  static const ctaTappedEvent = 'pro_visibility_lift_cta_tapped';
  static const dismissedEvent = 'pro_visibility_lift_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required ProVisibilityLiftResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({required ProVisibilityLiftResult result}) {
    _emit(
      ctaTappedEvent,
      result: result,
      actionType: ProVisibilityLiftActionType.seePro,
    );
  }

  static void dismissed({required ProVisibilityLiftResult result}) {
    _emit(
      dismissedEvent,
      result: result,
      actionType: ProVisibilityLiftActionType.dismiss,
    );
  }

  static void _emit(
    String event, {
    required ProVisibilityLiftResult result,
    ProVisibilityLiftActionType? actionType,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'surface': result.surface.analyticsValue,
      'entry_count': result.entryCount,
      'confidence_level': result.confidenceLevel.name,
      'has_paywall_seen': result.hasPaywallSeen ? 1 : 0,
    };
    if (actionType != null) {
      props['action_type'] = actionType.analyticsValue;
    }
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PRO_VISIBILITY_LIFT event=$event source=${result.source} '
        'surface=${result.surface.analyticsValue}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}