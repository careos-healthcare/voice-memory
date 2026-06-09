import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Main post-recording CTA — one sharp next prompt.
class NextEvidencePromptCard extends StatelessWidget {
  const NextEvidencePromptCard({
    super.key,
    required this.prompt,
    required this.onUsePrompt,
    required this.onChooseAnother,
    this.accent = true,
  });

  final String prompt;
  final VoidCallback onUsePrompt;
  final VoidCallback onChooseAnother;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final decoration = accent
        ? VoiceMemoryCards.standard(
            background: AppColors.accentPrimary.withValues(alpha: 0.08),
          ).copyWith(
            border: Border.all(
              color: AppColors.accentPrimary.withValues(alpha: 0.35),
            ),
          )
        : VoiceMemoryCards.standard(background: const Color(0xFFFFFBF5));

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.postSaveInsightRecordThisNext,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            prompt,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: gap),
          FilledButton(
            onPressed: onUsePrompt,
            child: Text(ConsumerUiCopy.postSaveInsightUseThisPrompt),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onChooseAnother,
            child: Text(ConsumerUiCopy.postSaveInsightChooseAnotherPrompt),
          ),
        ],
      ),
    );
  }
}
