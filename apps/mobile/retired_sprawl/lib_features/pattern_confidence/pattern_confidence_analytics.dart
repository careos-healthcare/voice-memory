import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/features/pattern_confidence/pattern_confidence_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:flutter/foundation.dart';

/// Safe analytics for pattern confidence explanations — metadata only.
abstract final class PatternConfidenceAnalytics {
  PatternConfidenceAnalytics._();

  static const seenEvent = 'pattern_confidence_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({
    required String source,
    required PatternConfidenceExplanationResult result,
  }) {
    final props = <String, Object>{
      'source': source,
      'entry_count': result.entryCount,
      'confidence_state': result.confidenceState.analyticsValue,
      'has_confirmed_repeat': result.hasConfirmedRepeat ? 1 : 0,
      'has_belief_surface': result.hasBeliefSurface ? 1 : 0,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
    if (kDebugMode) {
      AppLogger.debug(
        'ARCHIVEME_PATTERN_CONFIDENCE event=$seenEvent source=$source '
        'entry_count=${result.entryCount} confidence_state=${result.confidenceState.analyticsValue} '
        'has_confirmed_repeat=${result.hasConfirmedRepeat} '
        'has_belief_surface=${result.hasBeliefSurface}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}