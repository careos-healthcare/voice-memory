import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/timeline_performance_metrics.dart';

void main() {
  test('fromTimelineJson aggregates wall clock and sqlite spans', () {
    final metrics = TimelinePerformanceMetrics.fromTimelineJson({
      'traceEvents': [
        {
          'name': 'sqlite:query',
          'ph': 'X',
          'ts': 1_000,
          'dur': 500,
        },
        {
          'name': 'sqlite:transaction',
          'ph': 'X',
          'ts': 2_000,
          'dur': 1_500,
        },
        {
          'name': 'unrelated',
          'ph': 'X',
          'ts': 4_000,
          'dur': 100,
        },
      ],
    });

    expect(metrics.wallClockMicros, 3100);
    expect(metrics.sqliteOperationMicros, 2000);
    expect(metrics.sqliteOperationCount, 2);
    expect(metrics.eventCount, 3);
  });

  test('assertWithinBudget fails when wall clock exceeds cap', () {
    expect(
      () => TimelinePerformanceBudgets.assertWithinBudget(
        phase: 'sample',
        metrics: const TimelinePerformanceMetrics(
          wallClockMicros: 11_000,
          sqliteOperationMicros: 0,
          sqliteOperationCount: 0,
          eventCount: 0,
        ),
        budget: const TimelinePerformanceBudget(maxWallMs: 10),
      ),
      throwsA(isA<TestFailure>()),
    );
  });
}
