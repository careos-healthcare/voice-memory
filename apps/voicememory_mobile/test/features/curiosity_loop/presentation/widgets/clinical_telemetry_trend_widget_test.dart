import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/domain/services/telemetry_analytics_aggregator.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/models/telemetry_data_point.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/widgets/clinical_telemetry_trend_widget.dart';
import 'package:voicememory_mobile/features/curiosity_loop/presentation/widgets/connected_clinical_telemetry_trend_widget.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  final sampleSummaries = [
    WeeklyTelemetrySummary(
      weekStartDate: DateTime.utc(2026, 6, 9),
      totalObservations: 3,
      groundedInterventionsCount: 2,
      downRegulationSuccessRate: 100,
      averageLexicalDelta: 0.07,
      averageDriftDelta: 0.0,
    ),
    WeeklyTelemetrySummary(
      weekStartDate: DateTime.utc(2026, 6, 2),
      totalObservations: 1,
      groundedInterventionsCount: 0,
      downRegulationSuccessRate: 0,
      averageLexicalDelta: -0.02,
      averageDriftDelta: 0.20,
    ),
  ];

  group('ClinicalTelemetryTrendWidget', () {
    testWidgets('renders empty state when summaries are empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ClinicalTelemetryTrendWidget(summaries: []),
          ),
        ),
      );

      expect(
        find.text('No telemetry data available for this period.'),
        findsOneWidget,
      );
    });

    testWidgets('renders weekly down-regulation summary cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ClinicalTelemetryTrendWidget(summaries: sampleSummaries),
          ),
        ),
      );

      expect(find.text('Clinical Telemetry & Down-Regulation'), findsOneWidget);
      expect(find.text('Week of 2026-06-09'), findsOneWidget);
      expect(find.text('100% Regulated'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2 grounded'), findsOneWidget);
      expect(find.text('Week of 2026-06-02'), findsOneWidget);
    });
  });

  group('ConnectedClinicalTelemetryTrendWidget', () {
    testWidgets('aggregates trajectory points into weekly summaries',
        (tester) async {
      final dataPoints = [
        TelemetryDataPoint(
          date: DateTime.utc(2026, 6, 10),
          direction: CognitiveDirection.recovering,
          lexicalDelta: 0.20,
          driftDelta: -0.25,
          wasGrounded: true,
        ),
        TelemetryDataPoint(
          date: DateTime.utc(2026, 6, 11),
          direction: CognitiveDirection.stagnant,
          lexicalDelta: 0.02,
          driftDelta: 0.05,
          wasGrounded: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ConnectedClinicalTelemetryTrendWidget(
              history: dataPoints,
            ),
          ),
        ),
      );

      expect(find.text('Clinical Telemetry & Down-Regulation'), findsOneWidget);
      expect(find.byKey(const Key('clinical_telemetry_rolling_health_score')), findsOneWidget);
      expect(find.text('Rolling Stability Index'), findsOneWidget);
      expect(find.text('100 / 100'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      expect(find.text('Week of 2026-06-08'), findsOneWidget);
      expect(find.text('100% Regulated'), findsOneWidget);
      expect(find.text('2 grounded'), findsOneWidget);
    });
  });

  group('TelemetryDataPoint', () {
    test('recoveryIndex subtracts drift from lexical delta', () {
      final point = TelemetryDataPoint(
        date: DateTime.utc(2026, 6, 12),
        direction: CognitiveDirection.recovering,
        lexicalDelta: 0.20,
        driftDelta: -0.25,
      );

      expect(point.recoveryIndex, closeTo(0.45, 0.0001));
    });
  });
}
