import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_test_script/beta_test_script_copy.dart';
import 'package:archiveme_mobile/features/beta_test_script/beta_test_script_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact beta mission card on Record ready.
class BetaTestScriptCard extends StatelessWidget {
  const BetaTestScriptCard({
    required this.card, required this.onViewSteps, super.key,
    this.onSendFeedback,
  });

  final BetaTestScriptCompactCard card;
  final VoidCallback onViewSteps;
  final VoidCallback? onSendFeedback;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('beta_test_script_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F8FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            card.title,
            key: const Key('beta_test_script_card_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(
              context,
            ).copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            card.body,
            key: const Key('beta_test_script_card_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                key: const Key('beta_test_script_card_view_steps'),
                onPressed: onViewSteps,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  BetaTestScriptCopy.viewTestStepsCta,
                  style: ArchiveMobileTypography.responsiveHelper(context)
                      .copyWith(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                ),
              ),
              if (card.showSendFeedbackSecondary && onSendFeedback != null)
                TextButton(
                  key: const Key('beta_test_script_card_send_feedback'),
                  onPressed: onSendFeedback,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    BetaTestScriptCopy.sendBetaFeedbackCta,
                    style: ArchiveMobileTypography.responsiveHelper(context)
                        .copyWith(
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}