import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/pressure_loop_visibility_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// "Pressure loop visibility" card — simple, non-guilt weekly metrics.
class PressureLoopVisibilityCard extends StatelessWidget {
  const PressureLoopVisibilityCard({super.key, required this.visibility});

  final PressureLoopVisibility visibility;

  static const title = 'Your pressure loop, this week';
  static const emptyBody =
      'No pressure moments logged yet. Noticing one is enough to start.';
  static const guiltFreeLine = 'No streak guilt — noticing once still counts.';

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];

    if (!visibility.hasData) {
      lines.add(_line(context, emptyBody));
    } else {
      lines.add(_line(
        context,
        'You noticed pressure '
        '${_times(visibility.noticedThisWeek)} this week.',
      ));
      lines.add(const SizedBox(height: AppSpacing.xs));
      lines.add(_line(
        context,
        visibility.choseToStopCount > 0
            ? 'You chose to stop ${_times(visibility.choseToStopCount)}.'
            : "You haven't logged a stop yet — and that's okay.",
      ));
      final strongest = visibility.strongestPhrase;
      if (strongest != null) {
        lines.add(const SizedBox(height: AppSpacing.xs));
        lines.add(_line(context, 'Showed up most: "$strongest".'));
      }
      if (visibility.streakDays > 0) {
        lines.add(const SizedBox(height: AppSpacing.xs));
        lines.add(_line(
          context,
          'Noticed-the-loop streak: '
          '${visibility.streakDays} '
          'day${visibility.streakDays == 1 ? '' : 's'}.',
        ));
      }
    }

    return Container(
      key: const Key('pressure_loop_visibility_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FBFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...lines,
          const SizedBox(height: AppSpacing.sm),
          Text(
            guiltFreeLine,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.accentSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text) => Text(
        text,
        style: ArchiveMobileTypography.body(context).copyWith(
          color: AppColors.textPrimary,
        ),
      );

  static String _times(int count) => '$count time${count == 1 ? '' : 's'}';
}
