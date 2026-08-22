import 'package:archiveme_mobile/features/archive_growth/archive_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_copy.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_metrics.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_service.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Archive Growth Metrics V1 — confidence, evidence count, maturity level.
class ArchiveGrowthCard extends StatelessWidget {
  const ArchiveGrowthCard({
    required this.confidence, super.key,
    this.compact = false,
    this.showExplanation = true,
  });

  final ArchiveConfidenceView confidence;
  final bool compact;
  final bool showExplanation;

  @override
  Widget build(BuildContext context) {
    final metrics = ArchiveGrowthMetrics.fromConfidenceView(confidence);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MetricColumn(
                  key: const Key('archive_growth_confidence'),
                  label: ArchiveGrowthMetricsCopy.confidenceLabel,
                  value: ArchiveGrowthMetricsCopy.confidenceValue(
                    metrics.confidencePercent,
                  ),
                  compact: compact,
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  key: const Key('archive_growth_evidence'),
                  label: ArchiveGrowthMetricsCopy.evidenceLabel,
                  value: ArchiveGrowthMetricsCopy.evidenceValue(
                    metrics.evidenceCount,
                  ),
                  compact: compact,
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  key: const Key('archive_growth_maturity'),
                  label: ArchiveGrowthMetricsCopy.maturityLabel,
                  value: metrics.maturityLabel,
                  compact: compact,
                ),
              ),
            ],
          ),
          if (showExplanation && metrics.explanation.isNotEmpty) ...[
            SizedBox(height: compact ? 8 : 10),
            Text(
              metrics.explanation,
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: compact ? 11 : 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label, required this.value, required this.compact, super.key,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VoiceMemoryTypography.sectionLabelStyle().copyWith(
            fontSize: compact ? 10 : 11,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Loads growth metrics from the journal and shows [ArchiveGrowthCard] when evidence exists.
class ArchiveGrowthCardLoader extends StatelessWidget {
  const ArchiveGrowthCardLoader({
    super.key,
    this.compact = false,
    this.showExplanation = true,
  });

  final bool compact;
  final bool showExplanation;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ArchiveGrowthSnapshot?>(
      future: ArchiveGrowthService.load(),
      builder: (context, snapshot) {
        final growth = snapshot.data;
        if (growth == null || growth.confidence.maturity.recordingCount == 0) {
          return const SizedBox.shrink();
        }
        return ArchiveGrowthCard(
          confidence: growth.confidence,
          compact: compact,
          showExplanation: showExplanation,
        );
      },
    );
  }
}