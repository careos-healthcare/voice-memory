import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta/beta_activation_loop_tracker.dart';
import 'package:archiveme_mobile/features/pro_memory/pro_memory_boundary_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Compact upgrade bridge for longer archive memory surfaces.
class ProMemoryUpgradeBridge extends StatelessWidget {
  const ProMemoryUpgradeBridge({
    required this.onSeePro, super.key,
    this.onNotNow,
    this.compact = false,
    this.showNotNow = true,
  });

  final VoidCallback onSeePro;
  final VoidCallback? onNotNow;
  final bool compact;
  final bool showNotNow;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      unawaited(BetaActivationLoopTracker.trackProBoundarySeen());
    }

    return Container(
      key: Key(
        compact
            ? 'pro_memory_upgrade_bridge_compact'
            : 'pro_memory_upgrade_bridge',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProMemoryBoundaryCopy.upgradeBridgeTitle,
            key: const Key('pro_memory_upgrade_bridge_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProMemoryBoundaryCopy.upgradeBridgeBody,
            key: const Key('pro_memory_upgrade_bridge_body'),
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (showNotNow && onNotNow != null) ...[
                Expanded(
                  child: OutlinedButton(
                    key: const Key('pro_memory_upgrade_bridge_not_now'),
                    onPressed: onNotNow,
                    child: const Text(ProMemoryBoundaryCopy.notNowCta),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: FilledButton(
                  key: const Key('pro_memory_upgrade_bridge_see_pro'),
                  onPressed: onSeePro,
                  child: const Text(ProMemoryBoundaryCopy.seeProCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}