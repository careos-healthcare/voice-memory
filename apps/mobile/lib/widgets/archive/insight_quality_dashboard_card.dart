import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/insight_quality_dashboard.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Summary counts for the insight quality dashboard.
class InsightQualitySummaryCard extends StatelessWidget {
  const InsightQualitySummaryCard({required this.summary, super.key});

  final InsightQualitySummary summary;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);
    final valueStyle = ArchiveMobileTypography.responsiveBody(
      context,
    ).copyWith(color: AppColors.textPrimary);

    Widget row(String label, int count, Key key) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text('$count', key: key, style: valueStyle),
        ],
      ),
    );

    return Container(
      key: const Key('insight_quality_summary_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            VisibleArchiveProofCopy.insightQualitySummaryHeading,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          row(
            VisibleArchiveProofCopy.insightQualityFeelsRightLabel,
            summary.feelsRightCount,
            const Key('insight_quality_summary_feels_right'),
          ),
          row(
            VisibleArchiveProofCopy.insightQualityNotQuiteLabel,
            summary.notQuiteCount,
            const Key('insight_quality_summary_not_quite'),
          ),
          row(
            VisibleArchiveProofCopy.insightQualityHiddenLabel,
            summary.hiddenCount,
            const Key('insight_quality_summary_hidden'),
          ),
          row(
            VisibleArchiveProofCopy.insightQualityCorrectionNotesLabel,
            summary.correctionNoteCount,
            const Key('insight_quality_summary_correction_notes'),
          ),
        ],
      ),
    );
  }
}