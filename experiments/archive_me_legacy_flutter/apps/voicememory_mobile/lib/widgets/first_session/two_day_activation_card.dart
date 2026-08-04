import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_session/two_day_activation_engine.dart';
import '../../features/referral/invite_funnel_metrics.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact, passive card for the 2-day activation path. No buttons, no
/// streaks, no obligations — it never blocks recording and disappears on
/// its own once the path is complete.
class TwoDayActivationCard extends StatelessWidget {
  const TwoDayActivationCard({super.key, required this.path});

  final TwoDayActivationPath path;

  /// Funnel events: every 2-day card fires the generic seen event with its
  /// stage; the day-1-complete and day-2-return moments also fire their
  /// dedicated funnel steps. Stage ids only — never card text.
  void _trackSeen() {
    final stage = switch (path.stage) {
      TwoDayActivationStage.dayOneIntro => 'day_1',
      TwoDayActivationStage.dayOneComplete => 'day_1_complete',
      TwoDayActivationStage.dayTwoReturn => 'day_2_return',
      TwoDayActivationStage.none => null,
    };
    if (stage == null) return;
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.twoDayActivationSeen,
      stage: stage,
      oncePerSession: true,
    );
    if (path.stage == TwoDayActivationStage.dayOneComplete) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.day1CompleteSeen,
        oncePerSession: true,
      );
      // The concrete return reason renders with day-1 closure.
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.day1ReturnReasonSeen,
        oncePerSession: true,
      );
    }
    if (path.stage == TwoDayActivationStage.dayTwoReturn) {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.day2ReturnSeen,
        oncePerSession: true,
      );
      // Invited funnel mirror — additive, attribution-gated.
      InviteFunnelMetrics.dayTwoReturnSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!path.show) return const SizedBox.shrink();
    _trackSeen();

    return Container(
      key: const Key('two_day_activation_card'),
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
            path.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          for (final line in path.lines) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              line,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}
