import 'package:archiveme_mobile/billing/value_moment_paywall_trigger.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/referral/invite_funnel_metrics.dart';
import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Small, dismissible Pro bridge shown after a value moment. Inline card —
/// never a full-screen interruption, never blocks recording, and free users
/// keep everything they saved.
class ValueMomentProBridge extends StatelessWidget {
  const ValueMomentProBridge({
    required this.bridge, required this.onSeePro, required this.onDismiss, super.key,
  });

  final ValueMomentBridge bridge;
  final VoidCallback onSeePro;
  final VoidCallback onDismiss;

  /// Stable card-type id for analytics — null when unset, never user text.
  String? get _cardType => bridge.cardType.isEmpty ? null : bridge.cardType;

  @override
  Widget build(BuildContext context) {
    if (!bridge.show) return const SizedBox.shrink();
    final copy = LocalizedValueMomentBridge.from(context.l10n);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.valueMomentProBridgeSeen,
      source: 'value_moment',
      cardType: _cardType,
      oncePerSession: true,
    );

    return Container(
      key: const Key('value_moment_pro_bridge'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF1F5F2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            copy.bodyForCardType(bridge.cardType),
            key: const Key('value_moment_bridge_body'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                key: const Key('value_moment_dismiss'),
                onPressed: onDismiss,
                child: Text(copy.dismissLabel),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('value_moment_cta'),
                onPressed: () {
                  ActivationFunnelAnalytics.track(
                    ActivationFunnelAnalytics.valueMomentProBridgeTapped,
                    source: 'value_moment',
                    cardType: _cardType,
                  );
                  InviteFunnelMetrics.proBridgeTapped(bridge.cardType);
                  onSeePro();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                child: Text(
                  copy.ctaLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}