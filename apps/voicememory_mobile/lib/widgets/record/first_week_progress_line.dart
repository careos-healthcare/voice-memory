import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/retention/first_week_progress_model.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Small first-week progress line — no CTAs, no gamification.
class FirstWeekProgressLine extends StatelessWidget {
  const FirstWeekProgressLine({
    super.key,
    required this.progress,
    this.entryCount,
    this.surface = 'record',
  });

  final FirstWeekProgress progress;
  final int? entryCount;
  final String surface;

  String get _stateKey => switch (progress.state) {
    FirstWeekProgressState.day1 => 'day_1',
    FirstWeekProgressState.day2 => 'day_2',
    FirstWeekProgressState.firstProof => 'first_proof',
    FirstWeekProgressState.day3to7 => 'day_${progress.weekDay}',
  };

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.firstWeekProgressSeen,
      entryCount: entryCount ?? 0,
      source: surface,
      stage: _stateKey,
      oncePerSession: true,
    );

    return Padding(
      key: Key('first_week_progress_line_$_stateKey'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            progress.title,
            key: Key('first_week_progress_title_$_stateKey'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            progress.body,
            key: Key('first_week_progress_body_$_stateKey'),
            style: ArchiveMobileTypography.explanationBody(context).copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
