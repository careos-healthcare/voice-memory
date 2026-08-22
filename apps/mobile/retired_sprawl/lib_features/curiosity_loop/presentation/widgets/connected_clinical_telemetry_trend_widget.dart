import 'package:archiveme_mobile/features/curiosity_loop/domain/services/cognitive_trajectory_evaluator.dart';
import 'package:archiveme_mobile/features/curiosity_loop/domain/services/telemetry_analytics_aggregator.dart';
import 'package:archiveme_mobile/features/curiosity_loop/presentation/models/telemetry_data_point.dart';
import 'package:archiveme_mobile/features/curiosity_loop/presentation/widgets/clinical_telemetry_trend_widget.dart';
import 'package:flutter/material.dart';

class ConnectedClinicalTelemetryTrendWidget extends StatelessWidget {

  const ConnectedClinicalTelemetryTrendWidget({
    required this.history, super.key,
    this.evaluator = const CognitiveTrajectoryEvaluator(),
    this.aggregator = const TelemetryAnalyticsAggregator(),
  });
  final List<TelemetryDataPoint> history;
  final CognitiveTrajectoryEvaluator evaluator;
  final TelemetryAnalyticsAggregator aggregator;

  @override
  Widget build(BuildContext context) {
    final summaries = aggregator.calculateWeeklyTrends(history);

    if (summaries.isEmpty) {
      return const ClinicalTelemetryTrendWidget(summaries: []);
    }

    final score = evaluator.calculateRollingHealthScore(summaries);

    // Explicitly mapping the status thresholds
    final String statusLabel;
    final Color themeColor;

    if (score >= 75.0) {
      statusLabel = 'Stable';
      themeColor = Colors.green;
    } else if (score >= 50.0) {
      statusLabel = 'Monitoring';
      themeColor = Colors.orange;
    } else {
      statusLabel = 'Needs attention';
      themeColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          key: const Key('clinical_telemetry_rolling_health_score'),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rolling Stability Index',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on last 4 tracking cycles',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.toStringAsFixed(0)} / 100',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClinicalTelemetryTrendWidget(summaries: summaries),
      ],
    );
  }
}