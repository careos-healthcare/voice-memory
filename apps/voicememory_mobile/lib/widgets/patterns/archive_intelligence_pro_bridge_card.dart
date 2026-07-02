import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta/beta_activation_loop_tracker.dart';
import '../../design/archive_mobile_typography.dart';
import '../../features/archive_evidence/archive_belief_thread_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Soft Pro boundary for full archive history — never blocks insight or recording.
class ArchiveIntelligenceProBridgeCard extends StatelessWidget {
  const ArchiveIntelligenceProBridgeCard({
    super.key,
    required this.onSeePro,
    required this.onNotNow,
    this.compact = false,
  });

  final VoidCallback onSeePro;
  final VoidCallback onNotNow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      unawaited(BetaActivationLoopTracker.trackProBoundarySeen());
    }
    return Container(
      key: Key(
        compact
            ? 'archive_intelligence_pro_bridge_card_compact'
            : 'full_archive_history_pro_boundary_card',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ArchiveBeliefThreadCopy.fullArchiveHistoryTitle,
            key: const Key('full_archive_history_pro_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ArchiveBeliefThreadCopy.fullArchiveHistoryBody,
            key: const Key('full_archive_history_pro_body'),
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final bullet in ArchiveBeliefThreadCopy.fullArchiveHistoryBullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: ArchiveMobileTypography.body(context).copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: Text(
                    bullet,
                    key: Key('full_archive_history_pro_bullet_$bullet'),
                    style: ArchiveMobileTypography.body(context).copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            ArchiveBeliefThreadCopy.whyPro,
            key: const Key('full_archive_history_pro_why'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('archive_intelligence_pro_not_now'),
                  onPressed: onNotNow,
                  child: const Text(ArchiveBeliefThreadCopy.proBridgeSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('archive_intelligence_pro_see_pro'),
                  onPressed: onSeePro,
                  child: const Text(ArchiveBeliefThreadCopy.proBridgeCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
