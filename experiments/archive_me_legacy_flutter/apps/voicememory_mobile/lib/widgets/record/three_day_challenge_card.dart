import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/three_day_challenge/three_day_challenge_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Lightweight early-record guidance tracker — guidance only, no extra CTAs.
class ThreeDayChallengeCard extends StatelessWidget {
  const ThreeDayChallengeCard({super.key, required this.challenge});

  final ThreeDayChallengeState challenge;

  String get _dayKey => switch (challenge.day) {
    ThreeDayChallengeDay.day1 => 'day_1',
    ThreeDayChallengeDay.day2 => 'day_2',
    ThreeDayChallengeDay.day3 => 'day_3',
    ThreeDayChallengeDay.complete => 'complete',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('three_day_challenge_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7FAF6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            challenge.title,
            key: Key('three_day_challenge_title_$_dayKey'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            challenge.body,
            key: Key('three_day_challenge_body_$_dayKey'),
            style: ArchiveMobileTypography.explanationBody(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
