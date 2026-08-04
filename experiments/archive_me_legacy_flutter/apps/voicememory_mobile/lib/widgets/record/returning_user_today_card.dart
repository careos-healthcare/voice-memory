import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/activation/returning_user_today.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact Today card — return guidance on Record for users with saved entries.
class ReturningUserTodayCard extends StatelessWidget {
  const ReturningUserTodayCard({
    super.key,
    required this.model,
    required this.onPrimary,
    required this.onSecondary,
  });

  final ReturningUserToday model;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final labelStyle = ArchiveMobileTypography.responsiveHelper(context)
        .copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        );
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(
      context,
    ).copyWith(fontSize: 17);
    final bodyStyle = ArchiveMobileTypography.body(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);

    return Container(
      key: const Key('returning_user_today_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            VisibleArchiveProofCopy.returningUserTodaySectionLabel,
            key: const Key('returning_user_today_section_label'),
            style: labelStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            model.title,
            key: const Key('returning_user_today_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            model.body,
            key: const Key('returning_user_today_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonal(
            key: const Key('returning_user_today_primary_cta'),
            onPressed: onPrimary,
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(model.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('returning_user_today_secondary_cta'),
            onPressed: onSecondary,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(model.secondaryCta),
          ),
        ],
      ),
    );
  }
}
