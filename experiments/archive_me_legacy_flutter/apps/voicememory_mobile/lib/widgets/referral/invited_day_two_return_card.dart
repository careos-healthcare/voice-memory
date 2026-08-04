import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/referral/invite_funnel_metrics.dart';
import '../../features/referral/invited_day_two_return.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Invited Day 2 return card — source-tailored copy for the second visit,
/// shown in place of the generic Day 2 card for invited users. One optional
/// CTA into the existing recording/check flow; never blocks recording.
class InvitedDayTwoReturnCard extends StatelessWidget {
  const InvitedDayTwoReturnCard({
    super.key,
    required this.source,
    required this.entryCount,
    required this.onCheck,
  });

  /// Stable invite attribution source id; unknown values render the
  /// default copy.
  final String source;

  final int entryCount;

  /// Starts the existing recording/check flow — never a new flow.
  final VoidCallback onCheck;

  /// This card replaces the generic Day 2 card for invited users, so it
  /// keeps the normal Day 2 funnel events firing alongside the invited
  /// copy event. Stable ids and counts only — never card text.
  void _trackSeen() {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.twoDayActivationSeen,
      stage: 'day_2_return',
      oncePerSession: true,
    );
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.day2ReturnSeen,
      oncePerSession: true,
    );
    InviteFunnelMetrics.dayTwoReturnSeen();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.invitedDay2CopySeen,
      source: source,
      entryCount: entryCount,
      stage: 'day_2',
      oncePerSession: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    return Container(
      key: const Key('invited_day_two_return_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F6FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            InvitedDayTwoReturn.titleFor(source),
            key: const Key('invited_day_two_return_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            InvitedDayTwoReturn.bodyFor(source),
            key: const Key('invited_day_two_return_body'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('invited_day_two_return_cta'),
            onPressed: () {
              ActivationFunnelAnalytics.track(
                ActivationFunnelAnalytics.invitedDay2CopyTapped,
                source: source,
                entryCount: entryCount,
                stage: 'day_2',
              );
              onCheck();
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: const Text(InvitedDayTwoReturn.ctaLabel),
          ),
        ],
      ),
    );
  }
}
