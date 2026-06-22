import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/next_moment_prompt.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact personalized prompt — what moment to capture next.
class NextMomentPromptCard extends StatelessWidget {
  const NextMomentPromptCard({
    super.key,
    required this.prompt,
    required this.onPrimary,
    this.onSecondary,
    this.compact = false,
  });

  final NextMomentPrompt prompt;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final titleStyle = ArchiveMobileTypography.body(context).copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
      height: 1.35,
    );
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final padding = compact ? AppSpacing.sm : AppSpacing.sm + 4;

    return Container(
      key: const Key('next_moment_prompt_card'),
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary.withValues(alpha: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            VisibleArchiveProofCopy.nextMomentPromptSectionLabel,
            key: const Key('next_moment_prompt_section_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            prompt.title,
            key: const Key('next_moment_prompt_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            prompt.body,
            key: const Key('next_moment_prompt_body'),
            style: bodyStyle,
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('next_moment_prompt_primary_cta'),
              onPressed: onPrimary,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(prompt.primaryCta),
            ),
            if (onSecondary != null && prompt.secondaryCta != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('next_moment_prompt_secondary_cta'),
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(prompt.secondaryCta!),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
