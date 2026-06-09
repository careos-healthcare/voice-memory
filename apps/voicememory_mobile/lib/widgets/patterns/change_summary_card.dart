import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/tomorrow_return/change_summary_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../theme/voicememory_typography.dart';

class ChangeSummaryCard extends StatelessWidget {
  const ChangeSummaryCard({super.key, required this.summary});

  final ChangeSummary summary;

  @override
  Widget build(BuildContext context) {
    final chips = summary.chips.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.changeSummaryCardTitle,
            style: VoiceMemoryTypography.metadataStyle(
              color: AppColors.accentPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 17,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.summary,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in chips) _Chip(label: chip),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () => context.go('/belief-changes'),
              child: const Text(ConsumerUiCopy.tomorrowReturnStatusSeeChangedCta),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.bodyStyle().copyWith(fontSize: 13),
      ),
    );
  }
}
