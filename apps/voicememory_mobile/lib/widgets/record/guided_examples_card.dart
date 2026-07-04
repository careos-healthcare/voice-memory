import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/guided_examples_copy.dart';
import '../../features/onboarding/guided_examples_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Permissive recording examples for first-use Record — style guide only.
class GuidedExamplesCard extends StatelessWidget {
  const GuidedExamplesCard({
    super.key,
    required this.onUseStyle,
  });

  final ValueChanged<GuidedExample> onUseStyle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.cardLabel(context).copyWith(
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final exampleStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
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
      key: const Key('guided_examples_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFFAFAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            GuidedExamplesCopy.title,
            key: const Key('guided_examples_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            GuidedExamplesCopy.subtitle,
            key: const Key('guided_examples_subtitle'),
            style: subtitleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final example in GuidedExamplesCatalog.examples) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '"${example.text}"',
                    key: Key('guided_examples_text_${example.id}'),
                    style: exampleStyle,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: Key('guided_examples_use_style_${example.id}'),
                      onPressed: () => onUseStyle(example),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentPrimary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        GuidedExamplesCopy.useStyleCta,
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

/// Compact guided examples inside typed capture for early users.
class GuidedExamplesCapturePanel extends StatelessWidget {
  const GuidedExamplesCapturePanel({
    super.key,
    required this.onUseStyle,
    this.compact = false,
  });

  final ValueChanged<GuidedExample> onUseStyle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.cardLabel(context);
    final exampleStyle = ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.35,
      fontSize: 13,
    );
    final actionStyle = exampleStyle.copyWith(
      color: AppColors.accentPrimary,
      fontWeight: FontWeight.w600,
    );

    final visibleExamples = compact
        ? GuidedExamplesCatalog.examples.take(3)
        : GuidedExamplesCatalog.examples;

    return Column(
      key: const Key('guided_examples_capture_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          GuidedExamplesCopy.title,
          key: const Key('guided_examples_capture_title'),
          style: labelStyle,
        ),
        const SizedBox(height: 2),
        Text(
          GuidedExamplesCopy.subtitle,
          key: const Key('guided_examples_capture_subtitle'),
          style: exampleStyle,
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final example in visibleExamples)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                Text(
                  '"${example.text}"',
                  key: Key('guided_examples_capture_text_${example.id}'),
                  style: exampleStyle,
                ),
                TextButton(
                  key: Key('guided_examples_capture_use_style_${example.id}'),
                  onPressed: () => onUseStyle(example),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    GuidedExamplesCopy.useStyleCta,
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
