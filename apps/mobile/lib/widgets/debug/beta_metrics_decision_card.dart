import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/beta/beta_metrics_decision_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Internal beta metrics decision — developer diagnostics only.
class BetaMetricsDecisionCard extends StatelessWidget {
  const BetaMetricsDecisionCard({required this.report, super.key});

  final BetaMetricsDecisionReport report;

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(key: Key('beta_metrics_decision_hidden'));
    }

    return Container(
      key: const Key('beta_metrics_decision_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            report.title,
            key: const Key('beta_metrics_decision_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            report.summary,
            key: const Key('beta_metrics_decision_summary'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color:
                  report.primaryBottleneck ==
                      BetaMetricsDecisionBottleneck.healthy
                  ? AppColors.textPrimary
                  : AppColors.warning,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in report.rows) ...[
            _RowTile(row: row),
            const SizedBox(height: 10),
          ],
          if (report.coreValueFeedbackLabel != null &&
              report.coreValueFeedbackAnswer != null) ...[
            const SizedBox(height: 4),
            Text(
              report.coreValueFeedbackLabel!,
              key: const Key('beta_metrics_decision_core_value_feedback_label'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              report.coreValueFeedbackAnswer!,
              key: const Key(
                'beta_metrics_decision_core_value_feedback_answer',
              ),
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final BetaMetricsDecisionRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.metricName,
          key: Key('beta_metrics_decision_row_label_${row.id.name}'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Value: ${row.currentValue}',
          key: Key('beta_metrics_decision_row_value_${row.id.name}'),
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          'Target: ${row.targetValue}',
          key: Key('beta_metrics_decision_row_target_${row.id.name}'),
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        Text(
          'Status: ${row.status.label}',
          key: Key('beta_metrics_decision_row_status_${row.id.name}'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Text(
          'Fix: ${row.fixArea}',
          key: Key('beta_metrics_decision_row_fix_${row.id.name}'),
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
      ],
    );
  }
}