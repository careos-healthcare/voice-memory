import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for proof-connected paywall sharpening.
abstract final class PaywallValueSharpeningAnalytics {
  PaywallValueSharpeningAnalytics._();

  static const seenEvent = 'paywall_value_sharpening_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required String surface,
    required bool proofConnected,
    int? entryCount,
  }) {
    final properties = <String, Object>{
      'source': source,
      'surface': surface,
      'proof_connected': proofConnected ? 1 : 0,
      'entry_count': ?entryCount,
    };

    captureForTest?.call(seenEvent, properties);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PAYWALL_VALUE_SHARPENING event=$seenEvent source=$source '
        'surface=$surface proof_connected=$proofConnected '
        'entry_count=${entryCount ?? 'none'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
