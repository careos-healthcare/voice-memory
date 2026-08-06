import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'return_after_proof_lift_v2_copy.dart';
import 'return_after_proof_lift_v2_model.dart';

abstract final class ReturnAfterProofLiftV2Analytics {
  ReturnAfterProofLiftV2Analytics._();

  static const seenEvent = 'return_after_proof_lift_v2_seen';
  static const ctaTappedEvent = 'return_after_proof_lift_v2_cta_tapped';
  static const expandedEvent = 'return_after_proof_lift_v2_expanded';
  static const dismissedEvent = 'return_after_proof_lift_v2_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required ReturnAfterProofLiftV2Result result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({
    required ReturnAfterProofLiftV2Result result,
    required ReturnAfterProofLiftV2ActionType actionType,
  }) {
    _emit(
      actionType == ReturnAfterProofLiftV2ActionType.expandWatch
          ? expandedEvent
          : ctaTappedEvent,
      result: result,
      actionType: actionType,
    );
  }

  static void dismissed({required ReturnAfterProofLiftV2Result result}) {
    _emit(
      dismissedEvent,
      result: result,
      actionType: ReturnAfterProofLiftV2ActionType.dismiss,
    );
  }

  static void _emit(
    String event, {
    required ReturnAfterProofLiftV2Result result,
    ReturnAfterProofLiftV2ActionType? actionType,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'confidence_level': result.confidenceLevel.name,
      'has_anchor': result.hasAnchor ? 1 : 0,
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
      debugPrint(
        'ARCHIVEME_RETURN_AFTER_PROOF_LIFT_V2 event=$event source=${result.source} '
        'entry_count=${result.entryCount}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
