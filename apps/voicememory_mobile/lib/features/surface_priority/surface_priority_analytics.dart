import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'surface_priority_model.dart';

/// Safe metadata analytics for surface priority audit — no journal text.
abstract final class SurfacePriorityAnalytics {
  SurfacePriorityAnalytics._();

  static const seenEvent = 'surface_priority_audit_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({required SurfacePriorityResult result}) {
    final props = <String, Object>{
      'source': result.source,
      'surface': result.surface.name,
      'entry_count': result.entryCount,
      'visible_card_count': result.visibleCardCount,
      'suppressed_card_count': result.suppressedCardCount,
      if (result.proofCardKey != null) 'proof_card_key': result.proofCardKey!,
      if (result.guidanceCardKey != null)
        'guidance_card_key': result.guidanceCardKey!,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_SURFACE_PRIORITY event=$seenEvent surface=${result.surface.name} '
        'source=${result.source} entry_count=${result.entryCount} '
        'visible_card_count=${result.visibleCardCount} '
        'suppressed_card_count=${result.suppressedCardCount} '
        'proof_card_key=${result.proofCardKey} '
        'guidance_card_key=${result.guidanceCardKey}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
