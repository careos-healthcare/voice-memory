import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'beta_today_summary_model.dart';

/// Safe metadata analytics for beta today summary — no journal text.
abstract final class BetaTodaySummaryAnalytics {
  BetaTodaySummaryAnalytics._();

  static const seenEvent = 'beta_today_summary_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void seen({
    required BetaTodaySummaryResult result,
  }) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'has_confirmed_repeat': result.hasConfirmedRepeat ? 1 : 0,
      'has_correction': result.hasCorrection ? 1 : 0,
      'has_active_pattern': result.hasActivePattern ? 1 : 0,
      'has_fading_signal': result.hasFadingSignal ? 1 : 0,
    };
    captureForTest?.call(seenEvent, props);
    ActivationFunnelAnalytics.track(
      seenEvent,
      source: result.source,
      entryCount: result.entryCount,
      hasConfirmedRepeat: result.hasConfirmedRepeat,
    );
    if (kDebugMode) {
      debugPrint(
        'ARCHIVEME_BETA_TODAY_SUMMARY event=$seenEvent source=${result.source} '
        'entry_count=${result.entryCount} has_confirmed_repeat='
        '${result.hasConfirmedRepeat} has_correction=${result.hasCorrection} '
        'has_active_pattern=${result.hasActivePattern} '
        'has_fading_signal=${result.hasFadingSignal}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
