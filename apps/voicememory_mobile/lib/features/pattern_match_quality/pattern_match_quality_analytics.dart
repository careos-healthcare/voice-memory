import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'pattern_match_quality_model.dart';

/// Metadata-only analytics for pattern match quality resolution.
abstract final class PatternMatchQualityAnalytics {
  PatternMatchQualityAnalytics._();

  static const resolvedEvent = 'pattern_match_quality_resolved';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void resolved({
    required PatternMatchQualityResult result,
  }) {
    if (!result.shouldResolve) return;

    final props = <String, Object>{
      'entry_count': result.entryCount,
      'score_band': result.confidenceBand.analyticsValue,
      'matched_dimension_count': result.matchedDimensions.length,
      'weak_reason_count': result.weakReasons.length,
      'should_show_as_proof': result.shouldShowAsProof ? 1 : 0,
      'should_show_as_watch_only': result.shouldShowAsWatchOnly ? 1 : 0,
      'source': result.source,
    };
    captureForTest?.call(resolvedEvent, props);
    ActivationFunnelAnalytics.track(
      resolvedEvent,
      source: result.source,
      entryCount: result.entryCount,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_PATTERN_MATCH_QUALITY event=$resolvedEvent source=${result.source} '
        'entry_count=${result.entryCount} score_band=${result.confidenceBand.analyticsValue} '
        'matched_dimension_count=${result.matchedDimensions.length} '
        'weak_reason_count=${result.weakReasons.length} '
        'should_show_as_proof=${result.shouldShowAsProof} '
        'should_show_as_watch_only=${result.shouldShowAsWatchOnly}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
