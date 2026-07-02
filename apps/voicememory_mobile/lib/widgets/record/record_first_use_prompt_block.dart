import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta/beta_activation_loop_tracker.dart';
import '../../design/archive_mobile_typography.dart';
import '../../record/record_screen_framing_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Small first-use prompt inside the capture block — entry count 0 only.
class RecordFirstUsePromptBlock extends StatelessWidget {
  const RecordFirstUsePromptBlock({
    super.key,
    this.hideLeadCopy = false,
  });

  /// When the archive journey explainer is visible, step 1 already covers the
  /// lead title and body — keep examples and footer only.
  final bool hideLeadCopy;

  @override
  Widget build(BuildContext context) {
    unawaited(BetaActivationLoopTracker.trackFirstUsePromptSeen());
    final titleStyle = ArchiveMobileTypography.listTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final footerStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final chipStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
      fontSize: 13,
    );

    return Column(
      key: const Key('record_first_use_prompt_block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideLeadCopy) ...[
          Text(
            RecordFirstUsePromptCopy.title,
            key: const Key('record_first_use_prompt_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordFirstUsePromptCopy.body,
            key: const Key('record_first_use_prompt_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          RecordFirstUsePromptCopy.examplesHeading,
          key: const Key('record_first_use_prompt_examples_heading'),
          style: labelStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final example in RecordFirstUsePromptCopy.examples)
              Container(
                key: Key('record_first_use_prompt_example_$example'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(example, style: chipStyle),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          RecordFirstUsePromptCopy.footer,
          key: const Key('record_first_use_prompt_footer'),
          style: footerStyle,
        ),
      ],
    );
  }
}
