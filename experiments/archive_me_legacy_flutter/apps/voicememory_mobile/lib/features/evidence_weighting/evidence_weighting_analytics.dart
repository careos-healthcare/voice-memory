import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'evidence_weighting_model.dart';

/// Safe analytics for evidence weighting — metadata only.
abstract final class EvidenceWeightingAnalytics {
  EvidenceWeightingAnalytics._();

  static const seenEvent = 'evidence_weighting_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required EvidenceWeightingResult result,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': result.entryCount,
      'primary_state': result.primaryState.analyticsValue,
      'has_confirmed_repeat': result.hasConfirmedRepeat ? 1 : 0,
      'has_recent_entry': result.hasRecentEntry ? 1 : 0,
      'has_older_entry': result.hasOlderEntry ? 1 : 0,
      'has_softening_signal': result.hasSofteningSignal ? 1 : 0,
      'has_quiet_signal': result.hasQuietSignal ? 1 : 0,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_EVIDENCE_WEIGHTING event=$seenEvent source=$source '
        'entry_count=${result.entryCount} primary_state=${result.primaryState.analyticsValue} '
        'has_confirmed_repeat=${result.hasConfirmedRepeat} '
        'has_recent_entry=${result.hasRecentEntry} '
        'has_older_entry=${result.hasOlderEntry} '
        'has_softening_signal=${result.hasSofteningSignal} '
        'has_quiet_signal=${result.hasQuietSignal}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
