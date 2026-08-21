import 'dart:async';

import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_aggregator.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_drift_queries.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_models.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_onnx_synthesizer.dart';
import 'package:archiveme_mobile/features/insights/trend_analysis/trend_analysis_report_store.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_search_guard.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';

/// Background trend analysis over drift reflections + local ONNX synthesis.
class TrendAnalysisService {
  TrendAnalysisService({
    required JournalDatabase journalDatabase,
    required TrendAnalysisReportStore reportStore,
    required TrendAnalysisAggregator aggregator,
    required TrendAnalysisOnnxSynthesizer synthesizer,
    Duration debounce = const Duration(milliseconds: 500),
  }) : _journalDatabase = journalDatabase,
       _reportStore = reportStore,
       _aggregator = aggregator,
       _synthesizer = synthesizer,
       _debounce = debounce;

  final JournalDatabase _journalDatabase;
  final TrendAnalysisReportStore _reportStore;
  final TrendAnalysisAggregator _aggregator;
  final TrendAnalysisOnnxSynthesizer _synthesizer;
  final Duration _debounce;

  Timer? _debounceTimer;
  TrendAnalysisWindow _pendingWindow = TrendAnalysisWindow.sevenDay;
  var _flushInFlight = false;
  var _flushRescheduled = false;

  static Future<TrendAnalysisService> create({
    required JournalDatabase journalDatabase,
    required TrendAnalysisReportStore reportStore,
    TrendAnalysisAggregator? aggregator,
    TrendAnalysisOnnxSynthesizer? synthesizer,
  }) async {
    return TrendAnalysisService(
      journalDatabase: journalDatabase,
      reportStore: reportStore,
      aggregator: aggregator ?? const TrendAnalysisAggregator(),
      synthesizer:
          synthesizer ?? await TrendAnalysisOnnxSynthesizer.create(),
    );
  }

  void scheduleRefresh({
    TrendAnalysisWindow window = TrendAnalysisWindow.sevenDay,
  }) {
    _pendingWindow = window;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(flush(window: window));
    });
  }

  Future<WeeklySelfReflectionReport?> flush({
    TrendAnalysisWindow? window,
  }) async {
    if (_flushInFlight) {
      _flushRescheduled = true;
      return null;
    }

    _flushInFlight = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    try {
      WeeklySelfReflectionReport? latest;
      do {
        _flushRescheduled = false;
        final targetWindow = window ?? _pendingWindow;
        latest = await _generateReport(targetWindow);
      } while (_flushRescheduled);
      return latest;
    } finally {
      _flushInFlight = false;
    }
  }

  Future<WeeklySelfReflectionReport?> getCachedReport(
    TrendAnalysisWindow window,
  ) {
    return _reportStore.load(window);
  }

  Future<WeeklySelfReflectionReport?> _generateReport(
    TrendAnalysisWindow window,
  ) {
    return OfflineReflectionSearchGuard.runOffline(() async {
      final now = DateTime.now().toUtc();
      final windowEnd = DateTime.utc(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      );
      final windowStart = windowEnd
          .subtract(Duration(days: window.dayCount - 1))
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);

      final records = await TrendAnalysisDriftQueries.fetchReflectionRecordsInWindow(
        _journalDatabase,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );

      final metadata = _aggregator.aggregate(
        window: window,
        windowStart: windowStart,
        windowEnd: windowEnd,
        records: records,
      );
      if (metadata == null) return null;

      final synthesis = await _synthesizer.synthesize(metadata);
      final report = _synthesizer.composeReport(
        metadata: metadata,
        synthesis: synthesis.reflection,
        usedOnnx: synthesis.usedOnnx,
      );
      await _reportStore.save(report);
      return report;
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}

extension on DateTime {
  DateTime copyWith({
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
  }) {
    return DateTime.utc(
      year,
      month,
      day,
      hour ?? this.hour,
      minute ?? this.minute,
      second ?? this.second,
      millisecond ?? this.millisecond,
    );
  }
}
