import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/activation/first_three_session_copy.dart';
import 'package:archiveme_mobile/features/activation/third_session_archive_usefulness_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Session 3 — archive usefulness card for Patterns / archive surfaces.
class ThirdSessionArchiveUsefulnessCard extends StatelessWidget {
  const ThirdSessionArchiveUsefulnessCard({
    required this.usefulness, super.key,
  });

  final ThirdSessionArchiveUsefulness usefulness;

  @override
  Widget build(BuildContext context) {
    if (!usefulness.hasEnoughData) return const SizedBox.shrink();

    return Container(
      key: const Key('third_session_archive_usefulness_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF5F9F4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            FirstThreeSessionCopy.session3Title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: FirstThreeSessionCopy.session3KeepsReturning,
            body: usefulness.whatKeepsReturning,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Section(
            label: FirstThreeSessionCopy.session3ChangedSince,
            body: usefulness.whatChangedSince,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            FirstThreeSessionCopy.session3HonestMoment,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArchiveMobileTypography.cardLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          body,
          style: ArchiveMobileTypography.body(
            context,
          ).copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}