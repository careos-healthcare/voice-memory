import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/activation/activation_dropoff_review_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Internal-only activation funnel summary for beta QA — counts only.
class ActivationDropoffReviewCard extends StatelessWidget {
  const ActivationDropoffReviewCard({required this.review, super.key});

  final ActivationDropoffReview review;

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(
        key: Key('activation_dropoff_review_hidden'),
      );
    }

    return Container(
      key: const Key('activation_dropoff_review_card'),
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
            review.title,
            key: const Key('activation_dropoff_review_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final row in review.rows) ...[
            _RowTile(row: row),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            review.bottleneckLabel,
            key: const Key('activation_dropoff_review_bottleneck_label'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            review.bottleneckSummary,
            key: const Key('activation_dropoff_review_bottleneck_summary'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final ActivationDropoffRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            row.label,
            key: Key('activation_dropoff_row_label_${row.id.name}'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Text(
          '${row.count}',
          key: Key('activation_dropoff_row_count_${row.id.name}'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Text(
          row.status.label,
          key: Key('activation_dropoff_row_status_${row.id.name}'),
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
      ],
    );
  }
}