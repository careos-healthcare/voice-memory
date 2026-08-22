import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Metadata-only analytics for Pro moment timing — no journal text.
abstract final class ProMomentTimingAnalytics {
  ProMomentTimingAnalytics._();

  static const allowedEvent = 'pro_moment_allowed';
  static const blockedEvent = 'pro_moment_blocked';
  static const seenEvent = 'pro_moment_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void allowed({
    required String source,
    required String surface,
    required int entryCount,
    required String reason,
    required bool hasTimelineProof,
    required String feedbackState,
  }) {
    _emit(
      allowedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      reason: reason,
      hasTimelineProof: hasTimelineProof,
      feedbackState: feedbackState,
    );
  }

  static void blocked({
    required String source,
    required String surface,
    required int entryCount,
    required String blockedReason,
    required bool hasTimelineProof,
    required String feedbackState,
  }) {
    _emit(
      blockedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      blockedReason: blockedReason,
      hasTimelineProof: hasTimelineProof,
      feedbackState: feedbackState,
    );
  }

  static void seen({
    required String source,
    required String surface,
    required int entryCount,
    required String reason,
    required bool hasTimelineProof,
    required String feedbackState,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      reason: reason,
      hasTimelineProof: hasTimelineProof,
      feedbackState: feedbackState,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required String surface,
    required int entryCount,
    required bool hasTimelineProof, required String feedbackState, String? reason,
    String? blockedReason,
  }) {
    final props = <String, Object>{
      'source': source,
      'surface': surface,
      'entry_count': entryCount,
      'reason': ?reason,
      'blocked_reason': ?blockedReason,
      'has_timeline_proof': hasTimelineProof ? 1 : 0,
      'feedback_state': feedbackState,
    };
    captureForTest?.call(event, props);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      reason: reason ?? blockedReason,
      surfaceType: surface,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PRO_MOMENT_TIMING event=$event source=$source '
        'surface=$surface entry_count=$entryCount reason=${reason ?? 'none'} '
        'blocked_reason=${blockedReason ?? 'none'} '
        'has_timeline_proof=${hasTimelineProof ? 1 : 0} '
        'feedback_state=$feedbackState',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}