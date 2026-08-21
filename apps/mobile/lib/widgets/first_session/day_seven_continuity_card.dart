import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/first_session/day_seven_continuity_loop.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Day 7 Continuity card — a calm, passive note on where the archive is.
/// The single CTA appears only when the existing weekly review is genuinely
/// ready; while evidence is building the card asks for nothing and never
/// blocks recording.
class DaySevenContinuityCard extends StatelessWidget {
  const DaySevenContinuityCard({
    required this.loop, super.key,
    this.hasConnectedThread = false,
    this.entryCount = 0,
    this.onViewWeeklyReview,
  });

  final DaySevenContinuityLoop loop;

  /// Whether the existing thread evidence engine found a connected thread —
  /// analytics context only, never copy.
  final bool hasConnectedThread;

  final int entryCount;

  /// Opens the existing weekly review surface; required to render the CTA.
  final VoidCallback? onViewWeeklyReview;

  @override
  Widget build(BuildContext context) {
    if (!loop.show) return const SizedBox.shrink();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.day7ContinuitySeen,
      entryCount: entryCount,
      hasConnectedThread: hasConnectedThread,
      stage: loop.stageId,
      oncePerSession: true,
    );

    return Container(
      key: const Key('day_seven_continuity_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF4F6F9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loop.title,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            loop.body,
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          if (loop.helper.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              loop.helper,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (loop.hasCta && onViewWeeklyReview != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('day_seven_continuity_cta'),
              onPressed: () {
                ActivationFunnelAnalytics.track(
                  ActivationFunnelAnalytics.day7ContinuityWeeklyReviewTapped,
                  entryCount: entryCount,
                  hasConnectedThread: hasConnectedThread,
                  stage: loop.stageId,
                );
                onViewWeeklyReview!();
              },
              child: Text(loop.ctaLabel),
            ),
          ],
        ],
      ),
    );
  }
}