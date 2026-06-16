import 'dart:async';

import 'package:record/record.dart';

import 'audio_diag_log.dart';
import 'audio_silence_retry.dart';

class AudioLevelSummary {
  const AudioLevelSummary({
    required this.minDb,
    required this.maxDb,
    required this.avgDb,
    required this.sampleCount,
    required this.likelySilent,
  });

  final double minDb;
  final double maxDb;
  final double avgDb;
  final int sampleCount;
  final bool likelySilent;

  static const double silentThresholdDb = -45;
}

/// Samples recorder amplitude during capture and logs level diagnostics.
class AudioLevelMonitor {
  static const Duration silenceRetryWindow = AudioSilenceRetryPolicy.initialWindow;

  StreamSubscription<Amplitude>? _subscription;
  double _minDb = double.infinity;
  double _maxDb = double.negativeInfinity;
  double _sumDb = 0;
  int _sampleCount = 0;
  DateTime? _lastLogAt;

  double get currentMinDb =>
      _minDb.isFinite ? _minDb : double.negativeInfinity;

  double get currentMaxDb =>
      _maxDb.isFinite ? _maxDb : double.negativeInfinity;

  double get currentAvgDb =>
      _sampleCount > 0 ? _sumDb / _sampleCount : double.negativeInfinity;

  int get sampleCount => _sampleCount;

  bool shouldRetryForInitialSilence({required bool isIosPhysical}) =>
      AudioSilenceRetryPolicy.shouldRetryInitialSilence(
        isIosPhysical: isIosPhysical,
        retryAlreadyAttempted: false,
        maxDbInInitialWindow: currentMaxDb,
      );

  void start(AudioRecorder recorder) {
    stop(logSummary: false);
    resetStats();

    _subscription = recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amplitude) {
      _sampleCount += 1;
      final current = amplitude.current;
      _minDb = _min(_minDb, current);
      _maxDb = _max(_maxDb, amplitude.current);
      _maxDb = _max(_maxDb, amplitude.max);
      _sumDb += current;

      final now = DateTime.now();
      if (_lastLogAt == null ||
          now.difference(_lastLogAt!) >= const Duration(seconds: 1)) {
        _lastLogAt = now;
        AudioDiagLog.level(
          currentDb: current,
          minDb: currentMinDb,
          maxDb: currentMaxDb,
          avgDb: currentAvgDb,
        );
      }
    });
  }

  void resetStats() {
    _minDb = double.infinity;
    _maxDb = double.negativeInfinity;
    _sumDb = 0;
    _sampleCount = 0;
    _lastLogAt = null;
  }

  AudioLevelSummary stop({bool logSummary = true}) {
    _subscription?.cancel();
    _subscription = null;

    final resolvedMinDb =
        _minDb.isFinite ? _minDb : double.negativeInfinity;
    final resolvedMaxDb =
        _maxDb.isFinite ? _maxDb : double.negativeInfinity;
    final resolvedAvgDb = _sampleCount > 0
        ? _sumDb / _sampleCount
        : double.negativeInfinity;
    final likelySilent = _sampleCount == 0 ||
        resolvedMaxDb < AudioLevelSummary.silentThresholdDb;
    final summary = AudioLevelSummary(
      minDb: resolvedMinDb,
      maxDb: resolvedMaxDb,
      avgDb: resolvedAvgDb,
      sampleCount: _sampleCount,
      likelySilent: likelySilent,
    );

    if (logSummary) {
      AudioDiagLog.levelSummary(
        minDb: summary.minDb,
        maxDb: summary.maxDb,
        avgDb: summary.avgDb,
        sampleCount: summary.sampleCount,
        likelySilent: summary.likelySilent,
      );
    }

    return summary;
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
