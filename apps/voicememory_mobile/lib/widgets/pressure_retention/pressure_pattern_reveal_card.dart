import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/pressure_pattern_reveal_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Shows the user's recurring pressure pattern once there are 3+ entries.
///
/// Free users see the basic reveal + a locked "full pattern history" row.
/// Pro users see the extra detail: strongest trigger, likely cost, suggested
/// experiment, and confidence.
class PressurePatternRevealCard extends StatelessWidget {
  const PressurePatternRevealCard({
    super.key,
    required this.reveal,
    required this.isPro,
    required this.onTryInterruption,
    this.onUnlock,
  });

  final PressurePatternReveal reveal;
  final bool isPro;
  final VoidCallback onTryInterruption;

  /// Opens the Pro upgrade path from the locked history row (free only).
  final VoidCallback? onUnlock;

  static const title = 'Your pressure pattern';
  static const costsTitle = 'What this may be costing you';
  static const ctaLabel = 'Try one small interruption';
  static const lockedRowLabel = 'Unlock full pattern history';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_pattern_reveal_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F1FB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reveal.headline,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          if (reveal.hasPattern) ...[
            const SizedBox(height: AppSpacing.md),
            _costsSection(context),
            if (isPro) ...[
              const SizedBox(height: AppSpacing.md),
              _proDetail(context),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              _lockedHistoryRow(context),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('pressure_pattern_try_interruption'),
              onPressed: onTryInterruption,
              icon: const Icon(Icons.bolt_outlined),
              label: const Text(ctaLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _costsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(costsTitle, style: ArchiveMobileTypography.cardLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [for (final cost in reveal.costs) _costChip(context, cost)],
        ),
      ],
    );
  }

  Widget _costChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: ArchiveMobileTypography.responsiveHelper(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _proDetail(BuildContext context) {
    return Container(
      key: const Key('pressure_pattern_pro_detail'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reveal.strongestTrigger != null)
            _detailRow(
              context,
              'Strongest repeated trigger',
              reveal.strongestTrigger!,
            ),
          if (reveal.likelyCost != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _detailRow(context, 'Likely cost', reveal.likelyCost!),
          ],
          const SizedBox(height: AppSpacing.xs),
          _detailRow(
            context,
            'Suggested experiment',
            reveal.suggestedExperiment,
          ),
          const SizedBox(height: AppSpacing.xs),
          _detailRow(context, 'Confidence', reveal.confidence.label),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArchiveMobileTypography.cardLabel(context)),
        const SizedBox(height: 2),
        Text(
          value,
          style: ArchiveMobileTypography.body(
            context,
          ).copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _lockedHistoryRow(BuildContext context) {
    return InkWell(
      key: const Key('pressure_pattern_locked_history'),
      onTap: onUnlock,
      borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline,
              size: 18,
              color: AppColors.accentPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                lockedRowLabel,
                style: ArchiveMobileTypography.body(context).copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
