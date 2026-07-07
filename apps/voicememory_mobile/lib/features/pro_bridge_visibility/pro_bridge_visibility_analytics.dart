import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';

/// Metadata-only analytics for the post-proof Pro bridge visibility card.
abstract final class ProBridgeVisibilityAnalytics {
  ProBridgeVisibilityAnalytics._();

  static const seenEvent = 'pro_bridge_visibility_seen';
  static const ctaTappedEvent = 'pro_bridge_visibility_cta_tapped';
  static const dismissedEvent = 'pro_bridge_visibility_dismissed';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required String source,
    required String surface,
    required int entryCount,
    String? triggerReason,
    bool hasTimelineProof = false,
    String? feedbackState,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      triggerReason: triggerReason,
      hasTimelineProof: hasTimelineProof,
      feedbackState: feedbackState,
    );
  }

  static void ctaTapped({
    required String source,
    required String surface,
    required int entryCount,
    String? triggerReason,
    bool hasTimelineProof = false,
    String? feedbackState,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      triggerReason: triggerReason,
      hasTimelineProof: hasTimelineProof,
      feedbackState: feedbackState,
    );
  }

  static void dismissed({
    required String source,
    required String surface,
    required int entryCount,
    String? triggerReason,
    bool hasTimelineProof = false,
    String? feedbackState,
  }) {
    _emit(
      dismissedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      triggerReason: triggerReason,
      hasTimelineProof: hasTimelineProof,
      feedbackState: feedbackState,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required String surface,
    required int entryCount,
    String? triggerReason,
    bool hasTimelineProof = false,
    String? feedbackState,
  }) {
    final properties = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'surface': surface,
      if (triggerReason != null) 'trigger_reason': triggerReason,
      'has_timeline_proof': hasTimelineProof,
      if (feedbackState != null) 'feedback_state': feedbackState,
    };

    captureForTest?.call(event, properties);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      hasConfirmedRepeat: hasTimelineProof,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PRO_BRIDGE_VISIBILITY event=$event source=$source '
        'surface=$surface entry_count=$entryCount '
        'trigger_reason=${triggerReason ?? 'none'} '
        'has_timeline_proof=$hasTimelineProof '
        'feedback_state=${feedbackState ?? 'none'}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
