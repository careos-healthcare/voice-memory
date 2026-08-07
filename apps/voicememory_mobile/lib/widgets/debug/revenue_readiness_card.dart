import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../features/revenue_metrics/revenue_readiness_engine.dart';
import '../../features/revenue_metrics/revenue_readiness_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Developer-only beta revenue readiness dashboard — metadata only.
class RevenueReadinessCard extends StatelessWidget {
  const RevenueReadinessCard({super.key, required this.dashboard});

  final RevenueReadinessDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    if (!RevenueReadinessEngine.shouldShow(
      betaMissionEnabled: ArchiveBetaMissionGate.isEnabled,
    )) {
      return const SizedBox.shrink(key: Key('revenue_readiness_hidden'));
    }

    return Container(
      key: const Key('revenue_readiness_card'),
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
            dashboard.title,
            key: const Key('revenue_readiness_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            dashboard.subtitle,
            key: const Key('revenue_readiness_subtitle'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in dashboard.rows) ...[
            _RowTile(row: row),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Text(
            RevenueReadinessCopy.surfacesTitle,
            key: const Key('revenue_readiness_surfaces_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final surface in dashboard.surfaces) ...[
            _SurfaceTile(surface: surface),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final RevenueReadinessRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            row.label,
            key: Key('revenue_readiness_row_label_${row.id.name}'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(
          row.status.label,
          key: Key('revenue_readiness_row_status_${row.id.name}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: row.status == RevenueReadinessStatus.missing
                ? AppColors.warning
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({required this.surface});

  final RevenueReadinessSurface surface;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            surface.label,
            key: Key('revenue_readiness_surface_label_${surface.id}'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(
          surface.seen ? 'seen' : 'missing',
          key: Key('revenue_readiness_surface_status_${surface.id}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: surface.seen ? AppColors.textPrimary : AppTheme.muted,
          ),
        ),
      ],
    );
  }
}
