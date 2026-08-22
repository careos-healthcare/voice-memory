import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// Parsed performance stats from a VM timeline JSON blob emitted by
/// `IntegrationTestWidgetsFlutterBinding.traceAction`.
final class TimelinePerformanceMetrics {
  const TimelinePerformanceMetrics({
    required this.wallClockMicros,
    required this.sqliteOperationMicros,
    required this.sqliteOperationCount,
    required this.eventCount,
  });

  factory TimelinePerformanceMetrics.fromTimelineJson(
    Map<String, dynamic> timelineJson,
  ) {
    final rawEvents = timelineJson['traceEvents'];
    final events = rawEvents is List
        ? rawEvents.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const <Map<String, dynamic>>[];

    int? startMicros;
    int? endMicros;
    var sqliteMicros = 0;
    var sqliteCount = 0;

    for (final event in events) {
      final timestamp = event['ts'];
      if (timestamp is! num) {
        continue;
      }
      final ts = timestamp.toInt();
      final duration = switch (event['dur']) {
        final num value => value.toInt(),
        _ => 0,
      };
      final name = event['name']?.toString() ?? '';
      final phase = event['ph']?.toString() ?? '';

      startMicros = startMicros == null ? ts : math.min(startMicros!, ts);
      endMicros = endMicros == null ? ts + duration : math.max(endMicros!, ts + duration);

      if (name.startsWith('sqlite:') && phase == 'X' && duration > 0) {
        sqliteMicros += duration;
        sqliteCount++;
      }
    }

    return TimelinePerformanceMetrics(
      wallClockMicros: startMicros != null && endMicros != null
          ? endMicros! - startMicros!
          : 0,
      sqliteOperationMicros: sqliteMicros,
      sqliteOperationCount: sqliteCount,
      eventCount: events.length,
    );
  }

  final int wallClockMicros;
  final int sqliteOperationMicros;
  final int sqliteOperationCount;
  final int eventCount;

  double get wallClockMs => wallClockMicros / 1000;

  double get sqliteOperationMs => sqliteOperationMicros / 1000;

  Map<String, dynamic> toJson() => {
        'wallClockMs': wallClockMs,
        'sqliteOperationMs': sqliteOperationMs,
        'sqliteOperationCount': sqliteOperationCount,
        'eventCount': eventCount,
      };
}

/// Maximum allowed duration for a traced workflow phase.
final class TimelinePerformanceBudget {
  const TimelinePerformanceBudget({
    required this.maxWallMs,
    this.maxSqliteMs,
  });

  factory TimelinePerformanceBudget.fromJson(Map<String, dynamic> json) {
    return TimelinePerformanceBudget(
      maxWallMs: (json['maxWallMs'] as num).toDouble(),
      maxSqliteMs: json['maxSqliteMs'] == null
          ? null
          : (json['maxSqliteMs'] as num).toDouble(),
    );
  }

  final double maxWallMs;
  final double? maxSqliteMs;

  Map<String, dynamic> toJson() => {
        'maxWallMs': maxWallMs,
        if (maxSqliteMs != null) 'maxSqliteMs': maxSqliteMs,
      };
}

/// Loads regression budgets and asserts traced phases stay within them.
abstract final class TimelinePerformanceBudgets {
  TimelinePerformanceBudgets._();

  static const defaultAssetPath =
      'test/fixtures/performance/local_sync_query_performance_budgets.json';

  static Map<String, TimelinePerformanceBudget> load({
    String assetPath = defaultAssetPath,
  }) {
    final file = File(assetPath);
    if (!file.existsSync()) {
      return Map<String, TimelinePerformanceBudget>.from(_fallbackBudgets);
    }

    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw FormatException('Budget file must be a JSON object: $assetPath');
    }

    return decoded.map((key, value) {
      if (value is! Map) {
        throw FormatException('Budget "$key" must be a JSON object.');
      }
      return MapEntry(
        key,
        TimelinePerformanceBudget.fromJson(Map<String, dynamic>.from(value)),
      );
    });
  }

  static void assertWithinBudget({
    required String phase,
    required TimelinePerformanceMetrics metrics,
    required TimelinePerformanceBudget budget,
  }) {
    expect(
      metrics.wallClockMs,
      lessThanOrEqualTo(budget.maxWallMs),
      reason:
          '$phase wall clock ${metrics.wallClockMs.toStringAsFixed(1)}ms '
          'exceeds budget ${budget.maxWallMs}ms',
    );

    final sqliteCap = budget.maxSqliteMs;
    if (sqliteCap != null) {
      expect(
        metrics.sqliteOperationMs,
        lessThanOrEqualTo(sqliteCap),
        reason:
            '$phase sqlite aggregate ${metrics.sqliteOperationMs.toStringAsFixed(1)}ms '
            'exceeds budget ${sqliteCap}ms',
      );
    }
  }

  static const Map<String, TimelinePerformanceBudget> _fallbackBudgets = {
    'heavy_local_sync': TimelinePerformanceBudget(
      maxWallMs: 120_000,
      maxSqliteMs: 90_000,
    ),
    'encrypted_read_queries': TimelinePerformanceBudget(
      maxWallMs: 15_000,
      maxSqliteMs: 12_000,
    ),
    'fts5_full_text_search': TimelinePerformanceBudget(
      maxWallMs: 20_000,
      maxSqliteMs: 18_000,
    ),
  };
}

/// Writes updated budgets from observed metrics (observed × [safetyFactor]).
void writePerformanceBudgetsFromMetrics(
  Map<String, TimelinePerformanceMetrics> observed, {
  String outputPath = TimelinePerformanceBudgets.defaultAssetPath,
  double safetyFactor = 1.25,
}) {
  final budgets = observed.map((phase, metrics) {
    return MapEntry(
      phase,
      TimelinePerformanceBudget(
        maxWallMs: metrics.wallClockMs * safetyFactor,
        maxSqliteMs: metrics.sqliteOperationMs > 0
            ? metrics.sqliteOperationMs * safetyFactor
            : null,
      ),
    );
  });

  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(
      budgets.map((key, budget) => MapEntry(key, budget.toJson())),
    ),
  );
}
