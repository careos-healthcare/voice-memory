import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/beta/beta_release_qa_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Internal beta release QA — developer diagnostics only.
class BetaReleaseQaCard extends StatelessWidget {
  const BetaReleaseQaCard({required this.report, super.key});

  final BetaReleaseQaReport report;

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(key: Key('beta_release_qa_hidden'));
    }

    return Container(
      key: const Key('beta_release_qa_card'),
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
            key: const Key('beta_release_qa_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            report.summary,
            key: const Key('beta_release_qa_summary'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: report.readyForTesterBuild
                  ? AppColors.textPrimary
                  : AppColors.warning,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in report.rows) ...[
            _RowTile(row: row),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            report.manualChecklistTitle,
            key: const Key('beta_release_qa_manual_checklist_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < report.manualChecklistSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${i + 1}. ${report.manualChecklistSteps[i]}',
                key: Key('beta_release_qa_checklist_${i + 1}'),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            report.coreValueQuestionTitle,
            key: const Key('beta_release_qa_core_value_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            report.coreValueQuestion,
            key: const Key('beta_release_qa_core_value_question'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.coreValueFeedbackLabel,
            key: const Key('beta_release_qa_core_value_feedback_label'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            report.coreValueFeedbackAnswer,
            key: const Key('beta_release_qa_core_value_feedback_answer'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final BetaReleaseQaRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            row.label,
            key: Key('beta_release_qa_row_label_${row.id.name}'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (row.detail != null) ...[
          Text(
            row.detail!,
            key: Key('beta_release_qa_row_detail_${row.id.name}'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          row.status.label,
          key: Key('beta_release_qa_row_status_${row.id.name}'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}