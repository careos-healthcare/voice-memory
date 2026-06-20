import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';
import '../../features/archive_reactivity/archive_belief_specificity.dart';

/// Evidence-first belief detail header — quote-backed before generic sections.
class ArchiveBeliefSpecificitySection extends StatelessWidget {
  const ArchiveBeliefSpecificitySection({
    super.key,
    required this.specificity,
    this.onRecordCta,
  });

  final ArchiveBeliefSpecificity specificity;
  final VoidCallback? onRecordCta;

  static const wordsBehindTitle = 'The words behind this';
  static const noticedTitle = 'What ArchiveMe noticed';
  static const missionTitle = 'Next evidence mission';
  static const recordCta = 'Record this when it happens';

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('archive_belief_specificity_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          specificity.specificTitle,
          key: const Key('belief_specificity_title'),
          style: VoiceMemoryTypography.headlineStyle().copyWith(fontSize: 28),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          specificity.confidenceLabel,
          key: const Key('belief_specificity_confidence'),
          style: VoiceMemoryTypography.metadataStyle(
            color: AppColors.accentPrimary,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          specificity.evidenceSummaryLine,
          key: const Key('belief_specificity_evidence_summary'),
          style: VoiceMemoryTypography.bodyStyle(
            color: AppColors.textSecondary,
          ).copyWith(height: 1.45),
        ),
        if (specificity.hasQuotes) ...[
          const SizedBox(height: AppSpacing.lg),
          _QuoteCard(
            title: wordsBehindTitle,
            strongestQuote: specificity.strongestQuote,
            secondQuote: specificity.secondQuote,
            secondQuoteIntro: specificity.secondQuoteIntro,
          ),
        ],
        if (specificity.patternFromQuotesLine.isNotEmpty ||
            specificity.whatChangedLine.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            noticedTitle,
            style: VoiceMemoryTypography.sectionTitleStyle(),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (specificity.patternFromQuotesLine.isNotEmpty)
            Text(
              specificity.patternFromQuotesLine,
              key: const Key('belief_specificity_pattern'),
              style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
            ),
          if (specificity.whatChangedLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              specificity.whatChangedLine,
              key: const Key('belief_specificity_what_changed'),
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(height: 1.45),
            ),
          ],
        ],
        if (specificity.nextEvidenceMission.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            key: const Key('belief_specificity_mission_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  missionTitle,
                  style: VoiceMemoryTypography.cardTitleStyle(),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  specificity.nextEvidenceMission,
                  key: const Key('belief_specificity_next_mission'),
                  style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('belief_specificity_record_cta'),
                    onPressed:
                        onRecordCta ?? () => context.go('/record'),
                    child: const Text(recordCta),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.title,
    required this.strongestQuote,
    required this.secondQuote,
    required this.secondQuoteIntro,
  });

  final String title;
  final String strongestQuote;
  final String secondQuote;
  final String secondQuoteIntro;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('belief_specificity_quote_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0E7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VoiceMemoryTypography.cardTitleStyle()),
          const SizedBox(height: AppSpacing.sm),
          if (strongestQuote.isNotEmpty)
            Text(
              'You said: ‘$strongestQuote’',
              key: const Key('belief_specificity_strongest_quote'),
              style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
            ),
          if (secondQuote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            if (secondQuoteIntro.isNotEmpty)
              Text(
                secondQuoteIntro,
                key: const Key('belief_specificity_second_quote_context'),
                style: VoiceMemoryTypography.bodyStyle(
                  color: AppColors.textSecondary,
                ).copyWith(height: 1.45),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '‘$secondQuote’',
              key: const Key('belief_specificity_second_quote'),
              style: VoiceMemoryTypography.bodyStyle().copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}
