import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/archive_health_score.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact local-only archive health / evidence quality card.
class ArchiveHealthCard extends StatelessWidget {
  const ArchiveHealthCard({super.key, required this.score});

  final ArchiveHealthScore score;

  @override
  Widget build(BuildContext context) {
    if (!score.showCard) return const SizedBox.shrink();

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('archive_health_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            score.title,
            key: const Key('archive_health_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            score.subtitle,
            key: const Key('archive_health_subtitle'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.archiveHealthUsableMomentsLabel,
            key: const Key('archive_health_usable_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${score.usableMomentCount}',
            key: const Key('archive_health_usable_count'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.archiveHealthQualityLabel,
            key: const Key('archive_health_quality_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            score.statusLine,
            key: const Key('archive_health_status_line'),
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            score.evidenceQualityLine,
            key: const Key('archive_health_quality_line'),
            style: bodyStyle,
          ),
          if (score.statusBody.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              score.statusBody,
              key: const Key('archive_health_status_body'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (score.cautionLine case final caution?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caution,
              key: const Key('archive_health_caution_line'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (score.needsMoreEvidenceLines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              VisibleArchiveProofCopy.archiveHealthNeedsMoreLabel,
              key: const Key('archive_health_needs_more_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < score.needsMoreEvidenceLines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  score.needsMoreEvidenceLines[i],
                  key: Key('archive_health_needs_more_$i'),
                  style: bodyStyle,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.archiveHealthAddNextLabel,
            key: const Key('archive_health_add_next_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            score.whatToAddNextLine,
            key: const Key('archive_health_add_next_line'),
            style: bodyStyle,
          ),
        ],
      ),
    );
  }
}
