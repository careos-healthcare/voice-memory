import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/core_metrics_minimum/core_metrics_minimum_set_v2.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Developer-only release-beta metrics dashboard — classification wiring.
class CoreMetricsMinimumSetCard extends StatelessWidget {
  const CoreMetricsMinimumSetCard({required this.dashboard, super.key});

  final CoreMetricsMinimumDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(key: Key('core_metrics_minimum_set_hidden'));
    }

    return Container(
      key: const Key('core_metrics_minimum_set_card'),
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
            dashboard.headline,
            key: const Key('core_metrics_minimum_set_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            dashboard.body,
            key: const Key('core_metrics_minimum_set_body'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${dashboard.observedCoreCount}/${dashboard.rows.length} core metrics observed',
            key: const Key('core_metrics_minimum_set_summary'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            'Core beta metrics',
            key: const Key('core_metrics_minimum_set_section_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final row in dashboard.rows) ...[
            _MetricTile(row: row),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.row});

  final CoreMetricsMinimumDashboardRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                row.canonicalEvent,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              row.statusLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: row.observed ? AppColors.textPrimary : AppColors.warning,
              ),
            ),
            if (row.usedForPaidIntentDecision)
              const Text(
                'Paid-intent signal',
                style: TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}