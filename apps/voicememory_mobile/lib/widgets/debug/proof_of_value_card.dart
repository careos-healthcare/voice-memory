import 'package:flutter/material.dart';

import '../../config/developer_settings_gate.dart';
import '../../features/beta/proof_of_value_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Internal proof-of-value summary — developer diagnostics only.
class ProofOfValueCard extends StatelessWidget {
  const ProofOfValueCard({super.key, required this.report});

  final ProofOfValueReport report;

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(key: Key('proof_of_value_hidden'));
    }

    final summaryColor = report.summaryState == ProofOfValueSummaryState.strong
        ? AppColors.textPrimary
        : (report.summaryState == ProofOfValueSummaryState.emerging
              ? AppColors.textPrimary
              : AppColors.warning);

    return Container(
      key: const Key('proof_of_value_card'),
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
            key: const Key('proof_of_value_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            report.primaryQuestion,
            key: const Key('proof_of_value_primary_question'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.summary,
            key: const Key('proof_of_value_summary'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: summaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            report.recommendation,
            key: const Key('proof_of_value_recommendation'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (report.localCoreValueNote != null) ...[
            const SizedBox(height: 8),
            Text(
              report.localCoreValueNote!,
              key: const Key('proof_of_value_local_answer'),
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final row in report.rows) ...[
            _RowTile(row: row),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final ProofOfValueRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          key: Key('proof_of_value_row_label_${row.id.name}'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          row.question,
          key: Key('proof_of_value_row_question_${row.id.name}'),
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Value: ${row.currentValue}',
          key: Key('proof_of_value_row_value_${row.id.name}'),
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          'Target: ${row.targetValue}',
          key: Key('proof_of_value_row_target_${row.id.name}'),
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        Text(
          'Status: ${row.status.label}',
          key: Key('proof_of_value_row_status_${row.id.name}'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: row.status == ProofOfValueRowStatus.warning
                ? AppColors.warning
                : null,
          ),
        ),
      ],
    );
  }
}
