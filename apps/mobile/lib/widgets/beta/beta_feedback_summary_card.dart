import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_copy.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_engine.dart';
import 'package:archiveme_mobile/features/beta_feedback_intelligence/beta_feedback_intelligence_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Founder-facing beta signal summary — safe buckets only.
class BetaFeedbackSummaryCard extends StatelessWidget {
  const BetaFeedbackSummaryCard({
    required this.entries, super.key,
    this.summary,
  });

  final List<JournalEntry> entries;
  final BetaFeedbackIntelligenceSummary? summary;

  @override
  Widget build(BuildContext context) {
    final data =
        summary ??
        BetaFeedbackIntelligenceEngine.buildSummary(entries: entries);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.listTitle(
      context,
    ).copyWith(fontSize: 15);

    return Container(
      key: const Key('beta_feedback_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F8FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            BetaFeedbackIntelligenceCopy.summaryTitle,
            key: const Key('beta_feedback_summary_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: BetaFeedbackIntelligenceCopy.summaryFirstProofLabel,
            value: data.firstProofReachedLabel,
            keyName: 'beta_feedback_summary_first_proof',
            labelStyle: labelStyle,
            valueStyle: bodyStyle,
          ),
          _SummaryRow(
            label: BetaFeedbackIntelligenceCopy.summaryChatGptLabel,
            value: data.chatGptDifferenceLabel,
            keyName: 'beta_feedback_summary_chatgpt',
            labelStyle: labelStyle,
            valueStyle: bodyStyle,
          ),
          _SummaryRow(
            label: BetaFeedbackIntelligenceCopy.summaryProValueLabel,
            value: data.proValueLabel,
            keyName: 'beta_feedback_summary_pro_value',
            labelStyle: labelStyle,
            valueStyle: bodyStyle,
          ),
          _SummaryRow(
            label: BetaFeedbackIntelligenceCopy.summaryMainConfusionLabel,
            value: data.mainConfusionLabel,
            keyName: 'beta_feedback_summary_confusion',
            labelStyle: labelStyle,
            valueStyle: bodyStyle,
          ),
          _SummaryRow(
            label: BetaFeedbackIntelligenceCopy.summaryStrongestMomentLabel,
            value: data.strongestMomentLabel,
            keyName: 'beta_feedback_summary_strongest',
            labelStyle: labelStyle,
            valueStyle: bodyStyle,
          ),
          _SummaryRow(
            label: BetaFeedbackIntelligenceCopy.summaryFeedbackSubmittedLabel,
            value: data.feedbackSubmittedLabel,
            keyName: 'beta_feedback_summary_submitted',
            labelStyle: labelStyle,
            valueStyle: bodyStyle,
          ),
          if (data.reachedItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              BetaFeedbackIntelligenceCopy.reachedHeading,
              key: const Key('beta_feedback_summary_reached_heading'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final item in data.reachedItems)
              Text('• $item', style: bodyStyle),
          ],
          if (data.stillToTestItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              BetaFeedbackIntelligenceCopy.stillToTestHeading,
              key: const Key('beta_feedback_summary_still_heading'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final item in data.stillToTestItems)
              Text('• $item', style: bodyStyle),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.keyName,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final String keyName;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              key: Key('${keyName}_label'),
              style: labelStyle,
            ),
          ),
          Text(value, key: Key('${keyName}_value'), style: valueStyle),
        ],
      ),
    );
  }
}