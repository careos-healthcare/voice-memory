import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_beta_signal_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Compact beta link card for invite/support surfaces.
class CapacityBetaSignalCard extends StatelessWidget {
  const CapacityBetaSignalCard({super.key, this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('capacity_beta_signal_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            CapacityBetaSignalCopy.cardTitle,
            key: const Key('capacity_beta_signal_card_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CapacityBetaSignalCopy.cardBody,
            key: const Key('capacity_beta_signal_card_body'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('capacity_beta_signal_card_open'),
              onPressed:
                  onOpen ?? () => context.push(CapacityBetaSignalCopy.route),
              child: const Text(CapacityBetaSignalCopy.openDashboardButton),
            ),
          ),
        ],
      ),
    );
  }
}