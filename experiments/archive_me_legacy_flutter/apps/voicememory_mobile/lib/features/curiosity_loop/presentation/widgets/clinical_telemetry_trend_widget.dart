import 'package:flutter/material.dart';

import '../../domain/services/telemetry_analytics_aggregator.dart';

class ClinicalTelemetryTrendWidget extends StatelessWidget {
  final List<WeeklyTelemetrySummary> summaries;

  const ClinicalTelemetryTrendWidget({super.key, required this.summaries});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No telemetry data available for this period.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            'Clinical Telemetry & Down-Regulation',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: summaries.length,
          itemBuilder: (context, index) {
            final summary = summaries[index];
            final dateStr =
                '${summary.weekStartDate.year}-${summary.weekStartDate.month.toString().padLeft(2, '0')}-${summary.weekStartDate.day.toString().padLeft(2, '0')}';

            // Determine clinical status color based on success rate
            final Color statusColor = summary.downRegulationSuccessRate >= 75.0
                ? Colors.green
                : summary.downRegulationSuccessRate >= 50.0
                ? Colors.orange
                : Colors.red;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Week of $dateStr',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            '${summary.downRegulationSuccessRate.toStringAsFixed(0)}% Regulated',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MetricStat(
                          label: 'Observations',
                          value: '${summary.totalObservations}',
                          subtext:
                              '${summary.groundedInterventionsCount} grounded',
                        ),
                        _MetricStat(
                          label: 'Avg Lexical Δ',
                          value: summary.averageLexicalDelta.toStringAsFixed(2),
                          subtext: 'Vocabulary stability',
                        ),
                        _MetricStat(
                          label: 'Avg cohesion Δ',
                          value: summary.averageDriftDelta.toStringAsFixed(2),
                          subtext: 'Context retention',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MetricStat extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;

  const _MetricStat({
    required this.label,
    required this.value,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(subtext, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }
}
