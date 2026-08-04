// Public named parameters cannot expose private field names.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../services/analytics/analytics_catalog.dart';
import 'capture_performance_analytics.dart';
import 'capture_span.dart';

/// One completed measurement. Raw milliseconds live here and nowhere else.
@immutable
final class CaptureSpanSample {
  const CaptureSpanSample({required this.span, required this.milliseconds});

  final CaptureSpan span;
  final int milliseconds;

  /// The coarse band this sample would report.
  String get band =>
      AnalyticsCatalog.durationBand(Duration(milliseconds: milliseconds));

  @override
  String toString() => '${span.id}=${milliseconds}ms';
}

/// Receives a coarse band for a completed span. It cannot receive a duration.
typedef CaptureSpanBandSink = void Function(CaptureSpan span, String band);

/// Content-free capture latency instrumentation.
///
/// Raw millisecond values stay in this object, in memory, for the local
/// performance report. They are never persisted and never handed to an
/// analytics sink: [CaptureSpanBandSink] takes an already-banded string, so
/// there is no code path that could forward a timing.
final class CapturePerformanceTracker {
  CapturePerformanceTracker({
    CaptureSpanBandSink sink = CapturePerformanceAnalytics.emitBand,
    int maxSamplesPerSpan = 64,
  }) : _sink = sink,
       _maxSamplesPerSpan = maxSamplesPerSpan;

  /// The app-wide tracker. Replaceable so tests can observe a clean instance.
  static CapturePerformanceTracker instance = CapturePerformanceTracker();

  final CaptureSpanBandSink _sink;
  final int _maxSamplesPerSpan;
  final Map<CaptureSpan, Stopwatch> _open = <CaptureSpan, Stopwatch>{};
  final Map<CaptureSpan, List<int>> _samples = <CaptureSpan, List<int>>{};
  final Set<CaptureSpan> _reported = <CaptureSpan>{};

  // ---------------------------------------------------------------------
  // Capture lifecycle marks.
  //
  // These are deliberately named after product moments rather than taking a
  // [CaptureSpan], so the Record surface can call them without depending on
  // the span vocabulary.
  // ---------------------------------------------------------------------

  /// Dart `main()` entry. Native pre-main time is not visible here.
  void markAppLaunch() => _begin(CaptureSpan.appLaunchToRecordInteractive);

  /// The Record surface has painted a frame whose Record action is live.
  Duration? markRecordInteractive() =>
      _end(CaptureSpan.appLaunchToRecordInteractive);

  void markRecordTapped() => _begin(CaptureSpan.recordTapToRecording);

  Duration? markRecordingStarted() => _end(CaptureSpan.recordTapToRecording);

  void markStopTapped() => _begin(CaptureSpan.stopTapToEncryptedPersistence);

  /// The capture is sealed in the encrypted vault and committed to the journal.
  ///
  /// Idempotent per capture: the second call for the same capture is ignored so
  /// the save clock for the post-save spans is not pushed forward.
  Duration? markLocalSaveComplete() {
    if (!_open.containsKey(CaptureSpan.stopTapToEncryptedPersistence)) {
      return null;
    }
    final measured = _end(CaptureSpan.stopTapToEncryptedPersistence);
    markSaveCommitted();
    return measured;
  }

  /// A save completed outside the record-and-stop flow (typed capture).
  void markSaveCommitted() {
    _begin(CaptureSpan.saveToTranscriptVisible);
    _begin(CaptureSpan.saveToFirstValidObservation);
  }

  Duration? markTranscriptVisible() =>
      _end(CaptureSpan.saveToTranscriptVisible);

  Duration? markFirstValidObservationVisible() =>
      _end(CaptureSpan.saveToFirstValidObservation);

  /// A capture that failed or was discarded records no measurement.
  void markCaptureAbandoned() {
    _open.remove(CaptureSpan.stopTapToEncryptedPersistence);
    _open.remove(CaptureSpan.saveToTranscriptVisible);
    _open.remove(CaptureSpan.saveToFirstValidObservation);
  }

  // ---------------------------------------------------------------------
  // Local, in-memory reporting. Never persisted, never transmitted.
  // ---------------------------------------------------------------------

  bool isOpen(CaptureSpan span) => _open.containsKey(span);

  bool hasReported(CaptureSpan span) => _reported.contains(span);

  List<CaptureSpanSample> samplesFor(CaptureSpan span) => [
    for (final ms in _samples[span] ?? const <int>[])
      CaptureSpanSample(span: span, milliseconds: ms),
  ];

  List<CaptureSpanSample> get samples => [
    for (final span in CaptureSpan.values) ...samplesFor(span),
  ];

  int? p50MillisecondsFor(CaptureSpan span) => _percentile(span, 50);

  int? p95MillisecondsFor(CaptureSpan span) => _percentile(span, 95);

  int? maxMillisecondsFor(CaptureSpan span) {
    final values = _samples[span];
    if (values == null || values.isEmpty) return null;
    return values.reduce((a, b) => a > b ? a : b);
  }

  /// Human-readable local summary for the performance report.
  String localReport() {
    final lines = <String>[];
    for (final span in CaptureSpan.values) {
      final values = _samples[span] ?? const <int>[];
      if (values.isEmpty) {
        lines.add('${span.id}: no samples');
        continue;
      }
      lines.add(
        '${span.id}: n=${values.length} '
        'p50=${p50MillisecondsFor(span)}ms '
        'p95=${p95MillisecondsFor(span)}ms '
        'max=${maxMillisecondsFor(span)}ms '
        'band(p50)=${AnalyticsCatalog.durationBand(Duration(milliseconds: p50MillisecondsFor(span)!))}',
      );
    }
    return lines.join('\n');
  }

  void reset() {
    _open.clear();
    _samples.clear();
    _reported.clear();
  }

  int? _percentile(CaptureSpan span, int percentile) {
    final values = _samples[span];
    if (values == null || values.isEmpty) return null;
    final sorted = List<int>.of(values)..sort();
    final rank = ((percentile / 100) * (sorted.length - 1)).round();
    return sorted[rank];
  }

  void _begin(CaptureSpan span) {
    _open[span] = Stopwatch()..start();
  }

  Duration? _end(CaptureSpan span) {
    final stopwatch = _open.remove(span);
    if (stopwatch == null) return null;
    stopwatch.stop();
    final measured = stopwatch.elapsed;
    final bucket = _samples.putIfAbsent(span, () => <int>[]);
    if (bucket.length >= _maxSamplesPerSpan) bucket.removeAt(0);
    bucket.add(measured.inMilliseconds);
    // One band per span per app session keeps the funnel event counts honest
    // while still sampling latency across the installed base.
    if (_reported.add(span)) {
      _sink(span, AnalyticsCatalog.durationBand(measured));
    }
    return measured;
  }
}
