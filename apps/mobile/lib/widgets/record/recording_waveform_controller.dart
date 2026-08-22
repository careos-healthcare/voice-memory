import 'package:flutter/foundation.dart';

/// Ring buffer of normalized microphone levels (0–1) for live waveform rendering.
///
/// Updates call [ChangeNotifier.notifyListeners] only — parent widgets should not
/// rebuild on every amplitude sample.
class RecordingWaveformController extends ChangeNotifier {
  RecordingWaveformController({this.barCount = 40});

  static const double idleLevel = 0.06;

  final int barCount;
  late List<double> _levels = List<double>.filled(barCount, idleLevel);

  /// Current target bar heights; copied by the painter for smooth interpolation.
  List<double> get levels => _levels;

  /// Maps decibel readings from the `record` package to a 0–1 visual range.
  static double normalizeDb(double db) {
    const floor = -55.0;
    const ceiling = -8.0;
    if (!db.isFinite) return idleLevel;
    return ((db - floor) / (ceiling - floor)).clamp(idleLevel, 1.0);
  }

  void pushDb(double currentDb) => pushNormalized(normalizeDb(currentDb));

  void pushNormalized(double normalized) {
    final level = normalized.clamp(idleLevel, 1.0);
    for (var i = 0; i < barCount - 1; i++) {
      _levels[i] = _levels[i + 1];
    }
    _levels[barCount - 1] = level;
    notifyListeners();
  }

  void reset() {
    _levels = List<double>.filled(barCount, idleLevel);
    notifyListeners();
  }
}

/// Lightweight listenable used only to trigger [CustomPainter] repaints.
class RecordingWaveformRepaintNotifier extends ChangeNotifier {
  void markNeedsPaint() => notifyListeners();
}