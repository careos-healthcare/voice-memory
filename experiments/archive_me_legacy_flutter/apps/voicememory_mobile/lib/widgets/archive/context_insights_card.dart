import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/context_insights.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact card showing where tagged archive moments show up.
class ContextInsightsCard extends StatelessWidget {
  const ContextInsightsCard({super.key, required this.insights});

  final ContextInsights insights;

  @override
  Widget build(BuildContext context) {
    if (!insights.showCard) return const SizedBox.shrink();

    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final labelStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);

    return Container(
      key: const Key('context_insights_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            insights.title,
            key: const Key('context_insights_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insights.subtitle,
            key: const Key('context_insights_subtitle'),
            style: bodyStyle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insights.summaryLine,
            key: const Key('context_insights_summary'),
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          if (insights.detailLine case final detail?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail,
              key: const Key('context_insights_detail'),
              style: bodyStyle,
            ),
          ],
          if (insights.cautionLine case final caution?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caution,
              key: const Key('context_insights_caution'),
              style: bodyStyle.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (insights.topContexts.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              VisibleArchiveProofCopy.contextInsightsTopContextsLabel,
              key: const Key('context_insights_top_label'),
              style: labelStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (var i = 0; i < insights.topContexts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  '${insights.topContexts[i].label}: '
                  '${ContextInsightsEngine.momentCountLabel(insights.topContexts[i].count)}',
                  key: Key(
                    'context_insights_top_${insights.topContexts[i].tagId}',
                  ),
                  style: bodyStyle,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
