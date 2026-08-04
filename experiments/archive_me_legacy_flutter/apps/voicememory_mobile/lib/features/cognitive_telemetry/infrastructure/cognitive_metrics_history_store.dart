import 'package:flutter/foundation.dart';

import '../domain/cognitive_metrics.dart';

/// In-memory rolling history of acoustic cognitive telemetry snapshots.
class CognitiveMetricsHistoryStore extends ChangeNotifier {
  CognitiveMetricsHistoryStore({List<CognitiveMetrics>? seed})
    : _history = List<CognitiveMetrics>.from(seed ?? const []);

  static const maxEntries = 100;

  static CognitiveMetricsHistoryStore? _instance;

  final List<CognitiveMetrics> _history;

  List<CognitiveMetrics> get metricsHistory =>
      List<CognitiveMetrics>.unmodifiable(_history);

  void append(CognitiveMetrics metrics) {
    _history.add(metrics);
    if (_history.length > maxEntries) {
      _history.removeRange(0, _history.length - maxEntries);
    }
    notifyListeners();
  }

  static CognitiveMetricsHistoryStore instance() {
    return _instance ??= CognitiveMetricsHistoryStore();
  }

  static void clear() {
    _instance?._history.clear();
    _instance?.notifyListeners();
  }

  @visibleForTesting
  static void resetForTest() {
    clear();
    _instance = null;
  }
}
