import 'package:flutter/material.dart';

import '../../billing/paywall_objection_follow_up.dart';
import '../../billing/paywall_rejection_reason.dart';
import '../../design/archive_mobile_typography.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/voicememory_colors.dart';

/// One small objection-specific reassurance block on a future paywall —
/// keyed only by the stable rejection reason id. Passive: no buttons, no
/// CTA changes, and the copy never references the user's content.
class PaywallObjectionFollowUpCard extends StatelessWidget {
  const PaywallObjectionFollowUpCard({
    super.key,
    required this.reason,
    this.source,
  });

  final PaywallRejectionReason reason;

  /// Paywall source id for attribution. Never user text.
  final String? source;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.paywallObjectionFollowUpSeen,
      reason: reason.id,
      source: source,
      oncePerSession: true,
    );
    final copy = PaywallObjectionFollowUpCopy.forReason(reason);
    return Container(
      key: const Key('paywall_objection_follow_up'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: 6),
          Text(
            copy.body,
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
        ],
      ),
    );
  }
}
