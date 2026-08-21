import 'package:archiveme_mobile/design/archive_mobile_spacing.dart';
import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/consumer/consumer_screen_back_header.dart';
import 'package:flutter/material.dart';

class BeliefDetailScreen extends StatelessWidget {
  const BeliefDetailScreen({required this.belief, super.key});

  final ArchiveBeliefCardModel belief;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: ListView(
          padding: ArchiveMobileSpacing.pagePadding,
          children: [
            const ConsumerScreenBackHeader(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ConsumerUiCopy.patternDetailTitle,
              style: VoiceMemoryTypography.metadataStyle(
                color: AppColors.accentPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              belief.statement,
              style: VoiceMemoryTypography.headlineStyle().copyWith(
                fontSize: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${ConsumerUiCopy.labelConfidence}: ${belief.confidencePercent}%',
              style: VoiceMemoryTypography.sectionTitleStyle(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              belief.evidenceSummary,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              ConsumerUiCopy.labelWhy,
              style: VoiceMemoryTypography.cardTitleStyle(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              belief.whyExplanation,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ),
            ),
            if (belief.timeline.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                ConsumerUiCopy.detailMomentsSection,
                style: VoiceMemoryTypography.sectionTitleStyle(),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final q in belief.timeline)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.periodLabel,
                        style: VoiceMemoryTypography.metadataStyle(
                          color: AppColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(q.quote, style: VoiceMemoryTypography.bodyStyle()),
                    ],
                  ),
                ),
            ],
            if (belief.conclusion != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                ConsumerUiCopy.detailWhatThisMeans,
                style: VoiceMemoryTypography.sectionTitleStyle(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                belief.conclusion!,
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}