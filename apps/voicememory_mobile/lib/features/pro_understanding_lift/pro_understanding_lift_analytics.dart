import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'pro_understanding_lift_model.dart';

abstract final class ProUnderstandingLiftAnalytics {
  ProUnderstandingLiftAnalytics._();

  static const seenEvent = 'pro_understanding_lift_seen';
  static const ctaTappedEvent = 'pro_understanding_lift_cta_tapped';
  static const dismissedEvent = 'pro_understanding_lift_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required ProUnderstandingLiftResult result}) {
    _emit(seenEvent, result: result);
  }

  static void ctaTapped({required ProUnderstandingLiftResult result}) {
    _emit(ctaTappedEvent, result: result);
  }

  static void dismissed({required ProUnderstandingLiftResult result}) {
    _emit(dismissedEvent, result: result);
  }

  static void _emit(
    String event, {
    required ProUnderstandingLiftResult result,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'has_useful_proof': result.hasUsefulProof,
      'has_paywall_seen': result.hasPaywallSeen,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRO_UNDERSTANDING_LIFT event=$event source=${result.source} '
        'entry_count=${result.entryCount} has_useful_proof=${result.hasUsefulProof} '
        'has_paywall_seen=${result.hasPaywallSeen}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
