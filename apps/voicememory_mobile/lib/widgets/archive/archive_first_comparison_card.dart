import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/archive_first_comparison_display.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../features/post_save/post_save_focused_actions_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Archive tab — calm first-comparison proof surface for two saved moments.
class ArchiveFirstComparisonCard extends StatelessWidget {
  const ArchiveFirstComparisonCard({
    super.key,
    required this.display,
    required this.onViewEvidence,
    required this.onAddAnotherMoment,
  });

  final ArchiveFirstComparisonDisplay display;
  final VoidCallback onViewEvidence;
  final VoidCallback onAddAnotherMoment;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.body(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final evidenceStyle = bodyStyle.copyWith(fontStyle: FontStyle.italic);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final detailStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );

    return Container(
      key: const Key('archive_first_comparison_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0F7F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            display.title,
            key: const Key('archive_first_comparison_title'),
            style: titleStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            display.body,
            key: const Key('archive_first_comparison_body'),
            style: bodyStyle,
          ),
          if (display.evidenceLine case final evidence?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              evidence,
              key: const Key('archive_first_comparison_evidence_line'),
              style: evidenceStyle,
            ),
          ],
          if (display.whatChangedLine case final changed?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              display.hasGroundedPattern
                  ? VisibleArchiveProofCopy.archiveFirstComparisonWhatChangedLabel
                  : VisibleArchiveProofCopy.archiveFirstComparisonWhyMattersLabel,
              key: const Key('archive_first_comparison_detail_label'),
              style: labelStyle,
            ),
            const SizedBox(height: 4),
            Text(
              changed,
              key: const Key('archive_first_comparison_detail_line'),
              style: detailStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (display.primaryIsViewEvidence) ...[
            FilledButton(
              key: const Key('archive_first_comparison_view_evidence_cta'),
              onPressed: onViewEvidence,
              child: const Text(PostSaveFocusedActionsCopy.viewEvidence),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              key: const Key('archive_first_comparison_add_moment_cta'),
              onPressed: onAddAnotherMoment,
              child: const Text(PostSaveFocusedActionsCopy.addOneMoreMoment),
            ),
          ] else ...[
            FilledButton(
              key: const Key('archive_first_comparison_add_moment_cta'),
              onPressed: onAddAnotherMoment,
              child: const Text(PostSaveFocusedActionsCopy.addOneMoreMoment),
            ),
          ],
        ],
      ),
    );
  }
}
