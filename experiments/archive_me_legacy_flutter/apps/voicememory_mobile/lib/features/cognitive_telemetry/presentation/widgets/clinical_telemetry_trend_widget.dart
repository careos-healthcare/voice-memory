import 'package:flutter/material.dart';

import '../../domain/cognitive_metrics.dart';

class ClinicalTelemetryTrendWidget extends StatelessWidget {
  final List<CognitiveMetrics> metricsHistory;

  const ClinicalTelemetryTrendWidget({super.key, required this.metricsHistory});

  @override
  Widget build(BuildContext context) {
    if (metricsHistory.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No cognitive baseline data recorded yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final latest = metricsHistory.last;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cognitive Speech Baseline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _MetricRow(
              label: 'Lexical Diversity (TTR)',
              value: latest.lexicalDiversity,
              color: Colors.teal,
            ),
            const SizedBox(height: 8),
            _MetricRow(
              label: 'Emotional Volatility',
              value: latest.emotionalVolatility,
              color: Colors.amber.shade800,
            ),
            const SizedBox(height: 8),
            _MetricRow(
              label: 'Cohesion change',
              value: latest.cohesionDrift,
              color: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${(value * 100).toInt()}%',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          color: color,
          backgroundColor: color.withAlpha(40),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
