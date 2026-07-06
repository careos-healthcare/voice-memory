import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_use_wording/first_use_wording_copy.dart';
import '../../features/first_use_wording/first_use_wording_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Opening prompts for first-use Record — placeholder only, never saved.
class FirstUseWordingHelperCard extends StatelessWidget {
  const FirstUseWordingHelperCard({
    super.key,
    required this.onUseOpening,
  });

  final ValueChanged<FirstUseWordingPrompt> onUseOpening;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final promptStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.4,
      fontSize: 14,
    );
    final actionStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.accentPrimary,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );

    return Container(
      key: const Key('first_use_wording_helper_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFAFAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FirstUseWordingCopy.title,
            key: const Key('first_use_wording_helper_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            FirstUseWordingCopy.body,
            key: const Key('first_use_wording_helper_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final prompt in FirstUseWordingCatalog.prompts) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    prompt.opening,
                    key: Key('first_use_wording_prompt_${prompt.id}'),
                    style: promptStyle,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: Key('first_use_wording_use_opening_${prompt.id}'),
                      onPressed: () => onUseOpening(prompt),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentPrimary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        FirstUseWordingCopy.useOpeningCta,
                        style: actionStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact first-use wording helper inside typed capture for early users.
class FirstUseWordingCapturePanel extends StatelessWidget {
  const FirstUseWordingCapturePanel({
    super.key,
    required this.onUseOpening,
    this.compact = false,
  });

  final ValueChanged<FirstUseWordingPrompt> onUseOpening;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
      fontSize: 13,
    );
    final actionStyle = bodyStyle.copyWith(
      color: AppColors.accentPrimary,
      fontWeight: FontWeight.w600,
    );

    final visiblePrompts = compact
        ? FirstUseWordingCatalog.prompts.take(3)
        : FirstUseWordingCatalog.prompts;

    return Column(
      key: const Key('first_use_wording_capture_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          FirstUseWordingCopy.title,
          key: const Key('first_use_wording_capture_title'),
          style: labelStyle,
        ),
        const SizedBox(height: 2),
        Text(
          FirstUseWordingCopy.body,
          key: const Key('first_use_wording_capture_body'),
          style: bodyStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final prompt in visiblePrompts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                Text(
                  prompt.opening,
                  key: Key('first_use_wording_capture_prompt_${prompt.id}'),
                  style: bodyStyle,
                ),
                TextButton(
                  key: Key('first_use_wording_capture_use_opening_${prompt.id}'),
                  onPressed: () => onUseOpening(prompt),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    FirstUseWordingCopy.useOpeningCta,
                    style: actionStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
