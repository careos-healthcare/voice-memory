import 'dart:async';

import '../../services/analytics/analytics_catalog.dart';
import '../../services/product_analytics.dart';
import 'capture_span.dart';

/// The only analytics path this module has.
///
/// Two rules make a latency leak structurally impossible:
/// 1. This sink accepts a band [String], never a [Duration] and never a
///    millisecond count, so there is no argument a raw timing could arrive in.
/// 2. It emits exactly one property, [propertyKey], and only from
///    [AnalyticsCatalog.performanceDurationBands].
///
/// Every event id below is already registered in
/// `AnalyticsCatalog` as a V1 event; unregistered ids are rejected at runtime,
/// so no new event name is invented here.
abstract final class CapturePerformanceAnalytics {
  /// The single catalogued property key a latency band may use.
  static const String propertyKey = 'performance_duration_band';

  /// Registered V1 event each span attaches its band to.
  ///
  /// `first_capture_started` / `first_capture_saved` carry the two capture
  /// spans. The remaining three attach to the registered event that already
  /// marks the same product moment.
  static const Map<CaptureSpan, String> eventIds = {
    CaptureSpan.appLaunchToRecordInteractive: 'start_here_shown',
    CaptureSpan.recordTapToRecording: 'first_capture_started',
    CaptureSpan.stopTapToEncryptedPersistence: 'first_capture_saved',
    CaptureSpan.saveToTranscriptVisible: 'transcript_reviewed',
    CaptureSpan.saveToFirstValidObservation:
        'first_valid_observation_delivered',
  };

  /// Forwards [band] through the existing product analytics facade.
  static void emitBand(CaptureSpan span, String band) {
    if (!AnalyticsCatalog.performanceDurationBands.contains(band)) return;
    final event = eventIds[span];
    if (event == null) return;
    unawaited(
      ProductAnalytics.trackActivation(event, parameters: {propertyKey: band}),
    );
  }
}
