import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import 'beta_tester_report_model.dart';

/// Safe metadata analytics for beta tester report — no journal text.
abstract final class BetaTesterReportAnalytics {
  BetaTesterReportAnalytics._();

  static const seenEvent = 'beta_tester_report_seen';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
  captureForTest;

  static void seen({required BetaTesterReportResult result}) {
    final props = <String, Object>{
      'source': result.source,
      'entry_count': result.entryCount,
      'has_confirmed_repeat': result.hasConfirmedRepeat ? 1 : 0,
      'has_correction': result.hasCorrection ? 1 : 0,
      'has_fading_signal': result.hasFadingSignal ? 1 : 0,
      'has_softening_signal': result.hasSofteningSignal ? 1 : 0,
      'section_count': result.sectionCount,
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
        'ARCHIVEME_BETA_TESTER_REPORT event=$seenEvent source=${result.source} '
        'entry_count=${result.entryCount} has_confirmed_repeat='
        '${result.hasConfirmedRepeat} has_correction=${result.hasCorrection} '
        'has_fading_signal=${result.hasFadingSignal} '
        'has_softening_signal=${result.hasSofteningSignal} '
        'section_count=${result.sectionCount}',
      );
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
  }
}
