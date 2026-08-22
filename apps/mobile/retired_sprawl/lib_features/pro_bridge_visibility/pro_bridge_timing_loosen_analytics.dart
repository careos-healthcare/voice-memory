import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Metadata-only analytics for loosened Pro bridge timing.
abstract final class ProBridgeTimingLoosenAnalytics {
  ProBridgeTimingLoosenAnalytics._();

  static const seenEvent = 'pro_bridge_timing_loosen_seen';
  static const ctaTappedEvent = 'pro_bridge_timing_loosen_cta_tapped';
  static const blockedEvent = 'pro_bridge_timing_loosen_blocked';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required String surface,
    required int entryCount,
    required String triggerReason,
    String? confidenceLevel,
    bool hasSafeAnchor = false,
  }) {
    _emit(
      seenEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      triggerReason: triggerReason,
      confidenceLevel: confidenceLevel,
      hasSafeAnchor: hasSafeAnchor,
    );
  }

  static void ctaTapped({
    required String source,
    required String surface,
    required int entryCount,
    required String triggerReason,
    String? confidenceLevel,
    bool hasSafeAnchor = false,
  }) {
    _emit(
      ctaTappedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      triggerReason: triggerReason,
      confidenceLevel: confidenceLevel,
      hasSafeAnchor: hasSafeAnchor,
    );
  }

  static void blocked({
    required String source,
    required String surface,
    required int entryCount,
    required String blockedReason,
    String? confidenceLevel,
    bool hasSafeAnchor = false,
  }) {
    _emit(
      blockedEvent,
      source: source,
      surface: surface,
      entryCount: entryCount,
      blockedReason: blockedReason,
      confidenceLevel: confidenceLevel,
      hasSafeAnchor: hasSafeAnchor,
    );
  }

  static void _emit(
    String event, {
    required String source,
    required String surface,
    required int entryCount,
    String? triggerReason,
    String? blockedReason,
    String? confidenceLevel,
    bool hasSafeAnchor = false,
  }) {
    final properties = <String, Object>{
      'entry_count': entryCount,
      'source': source,
      'surface': surface,
      'trigger_reason': ?triggerReason,
      'blocked_reason': ?blockedReason,
      'confidence_level': ?confidenceLevel,
      'has_safe_anchor': hasSafeAnchor ? 1 : 0,
    };

    captureForTest?.call(event, properties);
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PRO_BRIDGE_TIMING_LOOSEN event=$event source=$source '
        'surface=$surface entry_count=$entryCount '
        'trigger_reason=${triggerReason ?? 'none'} '
        'blocked_reason=${blockedReason ?? 'none'} '
        'confidence_level=${confidenceLevel ?? 'none'} '
        'has_safe_anchor=$hasSafeAnchor',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}