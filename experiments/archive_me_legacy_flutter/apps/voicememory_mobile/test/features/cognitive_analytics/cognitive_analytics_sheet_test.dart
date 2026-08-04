import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cognitive_analytics/cognitive_metrics_models.dart';
import 'package:voicememory_mobile/features/cognitive_analytics/ui/cognitive_analytics_sheet.dart';

void main() {
  testWidgets('renders local charts and responds to time-range selection', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requested = <CognitiveTimeRange>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CognitiveAnalyticsSheet(
          loadSnapshot: (range) async {
            requested.add(range);
            return _snapshot(range);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('cognitive-valence-chart')), findsOneWidget);
    expect(find.byKey(const Key('cognitive-load-heatmap')), findsOneWidget);
    expect(find.byKey(const Key('cognitive-habit-chart')), findsOneWidget);
    expect(find.byKey(const Key('cognitive-insights-summary')), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pump();
    await tester.pump();

    expect(requested.last, CognitiveTimeRange.week);
    expect(
      find.text('Private · calculated only on this device'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows a gentle advisory when local burnout heuristics trigger', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CognitiveAnalyticsSheet(
          loadSnapshot: (range) async => _snapshot(range, advisory: true),
          onOpenCognitiveCouncil: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('cognitive-burnout-advisory')), findsOneWidget);
    expect(find.text('A gentler pace may help'), findsOneWidget);
    expect(find.byKey(const Key('cognitive-open-council')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

CognitiveMetricsSnapshot _snapshot(
  CognitiveTimeRange range, {
  bool advisory = false,
}) => CognitiveMetricsSnapshot(
  range: range,
  points: [
    for (var index = 0; index < 14; index++)
      CognitiveMetricPoint(
        day: DateTime.utc(2026, 7, 15 + index),
        valence: index / 20 - .3,
        movingAverage7: index / 25 - .2,
        movingAverage30: index / 30 - .15,
        movingAverage90: index / 40 - .1,
        cognitiveLoad: index / 14,
        semanticVelocity: .2 + index / 20,
        habitMomentum: index.isEven ? .7 : .35,
        sleepHours: 7.5 - index / 20,
        journalCount: 1,
        negativeClusterDensity: .2,
        activeNodeCount: index + 1,
        resolvedClusterCount: 3,
      ),
  ],
  insights: const [
    'Emotional tone is becoming steadier.',
    'Concept formation remains active.',
  ],
  advisory: advisory
      ? const BurnoutAdvisory(
          level: BurnoutRiskLevel.elevated,
          title: 'A gentler pace may help',
          message: 'Several local signals moved together for three days.',
          reasons: ['Declining sleep', 'Stalled momentum'],
        )
      : null,
);
