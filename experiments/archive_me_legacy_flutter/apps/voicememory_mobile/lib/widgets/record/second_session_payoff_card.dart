import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/second_session_payoff.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Second-entry payoff — one clear comparison moment after the second save.
class SecondSessionPayoffCard extends StatelessWidget {
  const SecondSessionPayoffCard({
    super.key,
    required this.payoff,
    required this.onAddAnother,
    required this.onViewArchive,
  });

  final SecondSessionPayoff payoff;
  final VoidCallback onAddAnother;
  final VoidCallback onViewArchive;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final footnoteStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('second_session_payoff_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            payoff.title,
            key: const Key('second_session_payoff_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            payoff.body,
            key: const Key('second_session_payoff_body'),
            style: bodyStyle,
          ),
          if (payoff.footnoteLine case final footnote?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              footnote,
              key: const Key('second_session_payoff_footnote'),
              style: footnoteStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('second_session_payoff_add_cta'),
            onPressed: onAddAnother,
            child: Text(payoff.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            key: const Key('second_session_payoff_view_archive_cta'),
            onPressed: onViewArchive,
            child: Text(payoff.secondaryCta),
          ),
        ],
      ),
    );
  }
}
