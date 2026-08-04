import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'paywall_cta_lift_model.dart';

abstract final class PaywallCtaLiftAnalytics {
  PaywallCtaLiftAnalytics._();

  static const seenEvent = 'paywall_cta_lift_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required PaywallCtaLiftResult result}) {
    final props = <String, Object>{
      'source': result.source,
      'proof_connected': result.proofConnected ? 1 : 0,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(seenEvent, source: result.source);
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PAYWALL_CTA_LIFT event=$seenEvent source=${result.source} '
        'proof_connected=${result.proofConnected}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
