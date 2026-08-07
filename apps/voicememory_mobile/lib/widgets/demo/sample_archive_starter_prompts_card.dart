import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_use_wording/first_use_wording_copy.dart';
import '../../features/first_use_wording/first_use_wording_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Example opening prompts on the sample archive — not shown on Record first screen.
class SampleArchiveStarterPromptsCard extends StatelessWidget {
  const SampleArchiveStarterPromptsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(fontWeight: FontWeight.w600);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);
    final promptStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4, fontSize: 14);

    return Container(
      key: const Key('sample_archive_starter_prompts_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFAFAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FirstUseWordingCopy.title,
            key: const Key('sample_archive_starter_prompts_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            FirstUseWordingCopy.body,
            key: const Key('sample_archive_starter_prompts_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final prompt in FirstUseWordingCatalog.prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                prompt.opening,
                key: Key('sample_archive_starter_prompt_${prompt.id}'),
                style: promptStyle,
              ),
            ),
        ],
      ),
    );
  }
}
