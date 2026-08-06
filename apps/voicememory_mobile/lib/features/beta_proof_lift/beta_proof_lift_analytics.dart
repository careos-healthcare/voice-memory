import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'beta_proof_lift_model.dart';

/// Metadata-only analytics for beta proof lift.
abstract final class BetaProofLiftAnalytics {
  BetaProofLiftAnalytics._();

  static const seenEvent = 'beta_proof_lift_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required String surface,
    required BetaProofLiftResult result,
  }) {
    final props = <String, Object>{
      'entry_count': result.entryCount,
      'source': source,
      'surface': surface,
      'has_safe_anchor': result.hasSafeAnchor ? 1 : 0,
      'has_delta': result.hasDelta ? 1 : 0,
      'has_current_relevance': result.hasCurrentRelevance ? 1 : 0,
      'has_correction': result.hasCorrection ? 1 : 0,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: result.entryCount,
      surfaceType: surface,
      hasConfirmedRepeat: result.hasSafeAnchor,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_PROOF_LIFT event=$seenEvent source=$source surface=$surface '
        'entry_count=${result.entryCount} has_safe_anchor=${result.hasSafeAnchor} '
        'has_delta=${result.hasDelta} has_current_relevance=${result.hasCurrentRelevance} '
        'has_correction=${result.hasCorrection}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
