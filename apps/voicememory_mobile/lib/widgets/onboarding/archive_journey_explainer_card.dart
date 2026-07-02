import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/archive_journey_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Evidence-first journey explainer — no CTAs, no blocking modals.
class ArchiveJourneyExplainerCard extends StatelessWidget {
  const ArchiveJourneyExplainerCard({
    super.key,
    required this.explainer,
  });

  final ArchiveJourneyExplainer explainer;

  bool get _compact =>
      explainer.variant == ArchiveJourneyExplainerVariant.compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = _compact
        ? ArchiveMobileTypography.responsiveHelper(context).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          )
        : ArchiveMobileTypography.responsiveSectionTitle(context);
    final stepTitleStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(
          fontWeight: FontWeight.w600,
          fontSize: _compact ? 13 : 14,
          color: AppColors.textPrimary,
        );
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      fontSize: _compact ? 13 : 14,
      height: 1.4,
    );

    return Container(
      key: Key(
        'archive_journey_explainer_card_${explainer.variant.name}',
      ),
      width: double.infinity,
      padding: EdgeInsets.all(_compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: _compact
            ? const Color(0xFFF7FAFC)
            : const Color(0xFFF5F9F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            explainer.title,
            key: const Key('archive_journey_explainer_title'),
            style: titleStyle,
          ),
          SizedBox(height: _compact ? AppSpacing.xs : AppSpacing.sm),
          for (var i = 0; i < explainer.steps.length; i++) ...[
            if (i > 0) SizedBox(height: _compact ? AppSpacing.xs : AppSpacing.sm),
            Text(
              explainer.steps[i].title,
              key: Key('archive_journey_explainer_step_title_$i'),
              style: stepTitleStyle,
            ),
            const SizedBox(height: 2),
            Text(
              explainer.steps[i].body,
              key: Key('archive_journey_explainer_step_body_$i'),
              style: bodyStyle,
            ),
          ],
        ],
      ),
    );
  }
}
