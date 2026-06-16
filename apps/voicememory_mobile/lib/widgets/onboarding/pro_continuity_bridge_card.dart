import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/onboarding/first_60_second_state.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// D. Pro continuity bridge — a soft explanation of what Pro continues,
/// shown only after repeat value in the archive. It never interrupts
/// recording, never hard-paywalls the first save, and keeps the promise on
/// continuity and archive usefulness.
class ProContinuityBridgeCard extends StatelessWidget {
  const ProContinuityBridgeCard({
    super.key,
    required this.entryCount,
    required this.source,
    required this.onSeePro,
    required this.onNotNow,
  });

  final int entryCount;

  /// Stable analytics source id only (e.g. 'record', 'archive').
  final String source;

  /// Opens the existing paywall — never a purchase call from here.
  final VoidCallback onSeePro;

  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.first60ProBridgeSeen,
      entryCount: entryCount,
      stage: First60Stage.proBridge.id,
      source: source,
      oncePerSession: true,
    );
    return Container(
      key: const Key('first_60_pro_bridge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            First60Copy.proTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            First60Copy.proBody,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('first_60_pro_bridge_not_now'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.first60ProBridgeDismissed,
                      entryCount: entryCount,
                      stage: First60Stage.proBridge.id,
                      source: source,
                    );
                    onNotNow();
                  },
                  child: const Text(First60Copy.proSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('first_60_pro_bridge_see_pro'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.first60ProBridgeTapped,
                      entryCount: entryCount,
                      stage: First60Stage.proBridge.id,
                      source: source,
                    );
                    onSeePro();
                  },
                  child: const Text(First60Copy.proCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
