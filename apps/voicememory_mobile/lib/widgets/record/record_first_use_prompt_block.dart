import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta_improvement/beta_improvement_pack_engine.dart';
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
    final footerStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
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
          if (BetaImprovementPackEngine.recordNotDiaryLine(entryCount: 0) !=
              null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              BetaImprovementPackEngine.recordNotDiaryLine(entryCount: 0)!,
              key: const Key('record_first_use_not_diary_line'),
              style: bodyStyle,
            ),
          ],
          if (BetaImprovementPackEngine.recordLowEvidenceClarifier(
                entryCount: 0,
              ) !=
              null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              BetaImprovementPackEngine.recordLowEvidenceClarifier(
                entryCount: 0,
              )!,
              key: const Key('record_first_use_clarifier_line'),
              style: footerStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          RecordFirstUsePromptCopy.footer,
          key: const Key('record_first_use_prompt_footer'),
          style: footerStyle,
        ),
      ],
    );
  }
}
