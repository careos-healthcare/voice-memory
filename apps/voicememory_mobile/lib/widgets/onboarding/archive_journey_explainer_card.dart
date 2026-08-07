import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/archive_journey_copy.dart';
import '../../features/onboarding/archive_journey_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Evidence-first journey explainer — no CTAs, no blocking modals.
class ArchiveJourneyExplainerCard extends StatelessWidget {
  const ArchiveJourneyExplainerCard({super.key, required this.explainer});

  final ArchiveJourneyExplainer explainer;

  bool get _compact =>
      explainer.variant == ArchiveJourneyExplainerVariant.compact;

  @override
  Widget build(BuildContext context) {
    if (_compact) {
      return _CompactLayout(explainer: explainer);
    }
    return _FullLayout(explainer: explainer);
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.explainer});

  final ArchiveJourneyExplainer explainer;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textSecondary,
        );
    final stepStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textPrimary,
        );
    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 12, height: 1.35);

    return Container(
      key: const Key('archive_journey_explainer_card_compact'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            explainer.title,
            key: const Key('archive_journey_explainer_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < explainer.steps.length; i++)
                Text(
                  '${i + 1}. ${explainer.steps[i].title}',
                  key: Key('archive_journey_explainer_step_title_$i'),
                  style: stepStyle,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            ArchiveJourneyCopy.compactHelper,
            key: const Key('archive_journey_explainer_compact_helper'),
            style: helperStyle,
          ),
        ],
      ),
    );
  }
}

class _FullLayout extends StatelessWidget {
  const _FullLayout({required this.explainer});

  final ArchiveJourneyExplainer explainer;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final stepTitleStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimary,
        );
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, fontSize: 14, height: 1.4);

    return Container(
      key: const Key('archive_journey_explainer_card_full'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF5F9F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            explainer.title,
            key: const Key('archive_journey_explainer_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < explainer.steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
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
