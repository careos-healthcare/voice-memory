import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_evidence/archive_belief_thread_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Simple privacy / trust card for Account and post-save surfaces.
class ArchivePrivacyTrustCard extends StatelessWidget {
  const ArchivePrivacyTrustCard({
    super.key,
    this.compact = false,
    this.onPrivacyTap,
  });

  final bool compact;
  final VoidCallback? onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('archive_privacy_trust_card'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.flat(
        background: const Color(0xFFF7F8FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveBeliefThreadCopy.trustTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
          Text(
            ArchiveBeliefThreadCopy.trustDelete,
            style: ArchiveMobileTypography.body(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBeliefThreadCopy.trustControl,
            style: ArchiveMobileTypography.body(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBeliefThreadCopy.trustNotTherapy,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          if (onPrivacyTap != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onPrivacyTap,
              child: const Text('Privacy'),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => context.push('/privacy'),
              child: const Text('Privacy'),
            ),
          ],
        ],
      ),
    );
  }
}
