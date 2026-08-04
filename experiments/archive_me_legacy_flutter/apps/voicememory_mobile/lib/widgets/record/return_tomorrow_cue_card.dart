import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/retention/return_tomorrow_cue_model.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Lightweight return-tomorrow guidance — no CTAs, no notifications.
class ReturnTomorrowCueCard extends StatelessWidget {
  const ReturnTomorrowCueCard({
    super.key,
    required this.cue,
    this.entryCount,
    this.surface = 'record',
  });

  final ReturnTomorrowCue cue;
  final int? entryCount;
  final String surface;

  String get _stateKey => switch (cue.state) {
    ReturnTomorrowCueState.afterFirstMoment => 'after_first_moment',
    ReturnTomorrowCueState.afterSecondRelated => 'after_second_related',
    ReturnTomorrowCueState.afterFirstProof => 'after_first_proof',
    ReturnTomorrowCueState.nextDayReturn => 'next_day_return',
  };

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.returnTomorrowSeen,
      entryCount: entryCount ?? 0,
      source: surface,
      stage: _stateKey,
      oncePerSession: true,
    );

    return Container(
      key: Key('return_tomorrow_cue_card_$_stateKey'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cue.title,
            key: Key('return_tomorrow_cue_title_$_stateKey'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            cue.body,
            key: Key('return_tomorrow_cue_body_$_stateKey'),
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
