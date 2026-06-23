import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/then_now/then_now_copy.dart';
import '../features/then_now/then_now_engine.dart';
import '../features/then_now/then_now_models.dart';
import '../models/journal_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact Then vs Now card for Archive Home — summarized signals only.
class ThenVsNowCard extends StatelessWidget {
  const ThenVsNowCard({
    super.key,
    required this.entries,
    required this.result,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.engine = const ThenNowEngine(),
    this.sampleMode = false,
  });

  const ThenVsNowCard.test({
    super.key,
    required this.entries,
    required this.result,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.engine = const ThenNowEngine(),
    this.sampleMode = false,
  });

  final List<JournalEntry> entries;
  final ThenNowResult result;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final ThenNowEngine engine;
  final bool sampleMode;

  @override
  Widget build(BuildContext context) {
    if (sampleMode ||
        ScreenshotMode.enabled ||
        !result.hasCard ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(key: Key('then_vs_now_card_hidden'));
    }

    return Container(
      key: const Key('then_vs_now_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ThenNowCopy.eyebrow,
            key: const Key('then_vs_now_card_eyebrow'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.headline,
            key: const Key('then_vs_now_card_headline'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.thenLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.thenSummary,
            key: const Key('then_vs_now_card_then_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.nowLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.nowSummary,
            key: const Key('then_vs_now_card_now_summary'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.evidenceCountLabel,
            key: const Key('then_vs_now_card_evidence'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.helperText,
            key: const Key('then_vs_now_card_helper'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('then_vs_now_card_primary_button'),
                onPressed: onPrimaryAction ??
                    () => context.push(result.primaryRoute),
                child: Text(result.primaryCtaLabel),
              ),
              OutlinedButton(
                key: const Key('then_vs_now_card_secondary_button'),
                onPressed: onSecondaryAction ??
                    () => context.push(result.secondaryRoute),
                child: Text(result.secondaryCtaLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
