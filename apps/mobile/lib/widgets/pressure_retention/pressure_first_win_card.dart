import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Stronger first-win moment shown after a user's very first pressure
/// check-in. Names what they just did so the value lands emotionally.
class PressureFirstWinCard extends StatelessWidget {
  const PressureFirstWinCard({required this.onSeeMeaning, super.key});

  final VoidCallback onSeeMeaning;

  static const title = 'Your archive has started.';
  static const body =
      'You just captured the kind of moment most people miss: the point where '
      'effort starts feeling like proof.';
  static const ctaLabel = 'See what this means';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_first_win_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.accentLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 20,
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('pressure_first_win_cta'),
            onPressed: onSeeMeaning,
            child: const Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}