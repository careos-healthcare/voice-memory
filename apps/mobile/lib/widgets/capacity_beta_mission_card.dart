import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_mission_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_mission_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact or full mission card for beta surfaces and Archive Home.
class CapacityBetaMissionCard extends StatelessWidget {
  const CapacityBetaMissionCard({
    required this.result, super.key,
    this.compact = false,
    this.onOpen,
    this.onDismiss,
  });

  final CapacityBetaMissionResult result;
  final bool compact;
  final VoidCallback? onOpen;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (!result.hasMission) {
      return const SizedBox.shrink(
        key: Key('capacity_beta_mission_card_hidden'),
      );
    }

    return Container(
      key: const Key('capacity_beta_mission_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            compact ? CapacityBetaMissionCopy.cardTitle : result.title,
            key: const Key('capacity_beta_mission_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            compact ? CapacityBetaMissionCopy.cardBody : result.subtitle,
            key: const Key('capacity_beta_mission_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.calmNote,
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.progressLabel,
            key: const Key('capacity_beta_mission_card_progress'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('capacity_beta_mission_card_open'),
              onPressed:
                  onOpen ?? () => context.push(CapacityBetaMissionCopy.route),
              child: Text(
                compact
                    ? CapacityBetaMissionCopy.viewMissionCta
                    : result.openMissionCta,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('capacity_beta_mission_card_dismiss'),
                onPressed: onDismiss,
                child: Text(result.dismissCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}