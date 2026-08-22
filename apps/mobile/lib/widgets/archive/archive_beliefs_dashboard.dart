import 'package:archiveme_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:archiveme_mobile/features/archive_beliefs/belief_change_timeline.dart';
import 'package:archiveme_mobile/product/belief_clarity.dart';
import 'package:archiveme_mobile/product/belief_product_copy.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/belief_clarity_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ArchiveHeroBeliefCard extends StatelessWidget {
  const ArchiveHeroBeliefCard({
    required this.belief, required this.reflectionsAnalysed, super.key,
  });

  final ArchiveBeliefCardModel belief;
  final int reflectionsAnalysed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: BeliefClarityCard(
        belief: belief,
        reflectionsAnalysed: reflectionsAnalysed,
        showArchiveExplanation: true,
        onTap: () => context.push('/belief-detail', extra: belief),
      ),
    );
  }
}

/// Story-first belief changes — narrative headline before detail.
class BeliefChangeStories extends StatelessWidget {
  const BeliefChangeStories({required this.items, super.key});

  final List<BeliefChangeTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        BeliefProductCopy.changesEmptyLead,
        style: VoiceMemoryTypography.bodyStyle(color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < items.length - 1 ? AppSpacing.md : 0,
            ),
            child: _StoryCard(item: items[i]),
          ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.item});

  final BeliefChangeTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.narrativeHeadline,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            BeliefClarity.quotedBelief(item.statement),
            style: VoiceMemoryTypography.bodyStyle(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.detail,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class ArchiveRecordEvidenceCta extends StatelessWidget {
  const ArchiveRecordEvidenceCta({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.addReflectionTitle,
          style: VoiceMemoryTypography.sectionTitleStyle(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          ConsumerUiCopy.addReflectionLead,
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: () => context.go('/record'),
          child: const Text(BeliefProductCopy.archiveRecordCta),
        ),
      ],
    );
  }
}

class BeliefSectionHeading extends StatelessWidget {
  const BeliefSectionHeading({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: VoiceMemoryTypography.headlineStyle().copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.35,
      ),
    );
  }
}