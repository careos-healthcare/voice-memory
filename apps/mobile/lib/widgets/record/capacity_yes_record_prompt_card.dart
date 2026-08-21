import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_loop_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Low-risk record prompt for capacity-yes users — no journal text.
class CapacityYesRecordPromptCard extends StatelessWidget {
  const CapacityYesRecordPromptCard({
    required this.onSaveMoment, super.key,
    this.showRecordCta = true,
  });

  final VoidCallback onSaveMoment;
  final bool showRecordCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('capacity_yes_record_prompt_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CapacityLoopCopy.recordPromptTitle,
            key: const Key('capacity_yes_record_prompt_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CapacityLoopCopy.recordPromptBody,
            key: const Key('capacity_yes_record_prompt_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (showRecordCta) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('capacity_yes_record_prompt_button'),
              onPressed: onSaveMoment,
              child: const Text(CapacityLoopCopy.saveYesMomentShortCta),
            ),
          ],
        ],
      ),
    );
  }
}