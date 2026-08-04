import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Soft Pro upgrade card used across the pressure insights surface.
///
/// Never blocks the free loop — it sits beside free content and points at the
/// existing ArchiveMe Pro subscription flow.
class PressureProUpgradeCard extends StatelessWidget {
  const PressureProUpgradeCard({
    super.key,
    required this.title,
    required this.body,
    required this.onUnlock,
  });

  final String title;
  final String body;
  final VoidCallback onUnlock;

  static const ctaLabel = 'See Pro';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_stories_outlined,
                size: 18,
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
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onUnlock, child: const Text(ctaLabel)),
        ],
      ),
    );
  }
}
