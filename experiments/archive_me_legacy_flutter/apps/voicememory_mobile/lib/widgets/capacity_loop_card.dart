import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/capacity_loop/capacity_loop_copy.dart';
import '../features/capacity_loop/capacity_loop_engine.dart';
import '../features/capacity_loop/capacity_loop_models.dart';
import '../models/journal_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact capacity yes loop card for Archive Home — counts only, no journal text.
class CapacityLoopCard extends StatelessWidget {
  const CapacityLoopCard({
    super.key,
    required this.entries,
    required this.result,
    required this.capacityLoopActive,
    required this.capacityCohortActive,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.engine = const CapacityLoopEngine(),
    this.sampleMode = false,
  });

  const CapacityLoopCard.test({
    super.key,
    required this.entries,
    required this.result,
    this.capacityLoopActive = true,
    this.capacityCohortActive = false,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.engine = const CapacityLoopEngine(),
    this.sampleMode = false,
  });

  final List<JournalEntry> entries;
  final CapacityLoopResult result;
  final bool capacityLoopActive;
  final bool capacityCohortActive;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final CapacityLoopEngine engine;
  final bool sampleMode;

  @override
  Widget build(BuildContext context) {
    if (sampleMode ||
        ScreenshotMode.enabled ||
        !result.hasCard ||
        !result.showOnArchiveHome) {
      return const SizedBox.shrink(key: Key('capacity_loop_card_hidden'));
    }

    return Container(
      key: const Key('capacity_loop_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.title,
            key: const Key('capacity_loop_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.subtitle,
            key: const Key('capacity_loop_card_subtitle'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (result.evidenceCountLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.evidenceCountLabel,
              key: const Key('capacity_loop_card_evidence'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (result.outcomeEvidenceLabel.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.outcomeEvidenceLabel,
              key: const Key('capacity_loop_card_outcome_evidence'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (result.pullReasonSummary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.pullReasonSummary,
              key: const Key('capacity_loop_card_pull_reason'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _loopRow(
            context,
            label: result.triggerLabel,
            value: CapacityLoopCopy.recordPromptTitle,
            valueKey: 'capacity_loop_card_trigger',
          ),
          _loopRow(
            context,
            label: result.saidYesLabel,
            value: CapacityLoopCopy.loopDiagramSaidYes,
            valueKey: 'capacity_loop_card_said_yes',
          ),
          _loopRow(
            context,
            label: result.costLaterLabel,
            value: result.costLater,
            valueKey: 'capacity_loop_card_cost_later',
          ),
          _loopRow(
            context,
            label: result.repeatedLabel,
            value: result.whatRepeated,
            valueKey: 'capacity_loop_card_what_repeated',
          ),
          _loopRow(
            context,
            label: result.watchNextLabel,
            value: result.watchNext,
            valueKey: 'capacity_loop_card_watch_next',
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('capacity_loop_card_primary_button'),
                onPressed:
                    onPrimaryAction ?? () => context.push(result.primaryRoute),
                child: Text(result.primaryCtaLabel),
              ),
              OutlinedButton(
                key: const Key('capacity_loop_card_secondary_button'),
                onPressed:
                    onSecondaryAction ??
                    () => context.push(result.secondaryRoute),
                child: Text(result.secondaryCtaLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loopRow(
    BuildContext context, {
    required String label,
    required String value,
    required String valueKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            key: Key(valueKey),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
      ),
    );
  }
}
