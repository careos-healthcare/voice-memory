import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/domain/cognitive_metrics.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/infrastructure/cognitive_metrics_history_store.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/presentation/widgets/clinical_telemetry_trend_widget.dart';
import 'package:voicememory_mobile/features/cognitive_telemetry/presentation/widgets/connected_cognitive_telemetry_trend_widget.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

void main() {
  tearDown(CognitiveMetricsHistoryStore.resetForTest);

  final sampleMetrics = [
    CognitiveMetrics(
      sessionId: 'session_1',
      timestamp: DateTime.utc(2026, 7, 20, 12),
      lexicalDiversity: 0.72,
      emotionalVolatility: 0.31,
      cohesionDrift: 0.18,
      pauseDurationTotal: Duration(seconds: 4),
    ),
  ];

  group('ClinicalTelemetryTrendWidget', () {
    testWidgets('renders empty state when history is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ClinicalTelemetryTrendWidget(metricsHistory: []),
          ),
        ),
      );

      expect(
        find.text('No cognitive baseline data recorded yet.'),
        findsOneWidget,
      );
    });

    testWidgets('renders latest cognitive metrics as progress rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ClinicalTelemetryTrendWidget(metricsHistory: sampleMetrics),
          ),
        ),
      );

      expect(find.text('Cognitive Speech Baseline'), findsOneWidget);
      expect(find.text('Lexical Diversity (TTR)'), findsOneWidget);
      expect(find.text('Emotional Volatility'), findsOneWidget);
      expect(find.text('Cohesion change'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('31%'), findsOneWidget);
      expect(find.text('18%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });
  });

  group('ConnectedCognitiveTelemetryTrendWidget', () {
    testWidgets('rebuilds when metrics history store updates', (tester) async {
      final store = CognitiveMetricsHistoryStore();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ConnectedCognitiveTelemetryTrendWidget(store: store),
          ),
        ),
      );

      expect(
        find.text('No cognitive baseline data recorded yet.'),
        findsOneWidget,
      );

      store.append(sampleMetrics.first);
      await tester.pump();

      expect(find.text('Cognitive Speech Baseline'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
    });
  });
}
