import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/pressure_retention/pressure_evidence_confidence.dart';
import '../../features/pressure_retention/pressure_insights_copy.dart';
import '../../features/pressure_retention/pressure_loop_visibility_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'pressure_confidence_label.dart';

/// "Pressure loop visibility" card — simple, non-guilt weekly metrics.
///
/// Free users see a basic version (count + chose-to-stop). Pro users see the
/// full card with the strongest pressure, the streak, and an evidence
/// confidence label.
class PressureLoopVisibilityCard extends StatelessWidget {
  const PressureLoopVisibilityCard({
    super.key,
    required this.visibility,
    this.locked = false,
    this.confidence,
    this.entryCount = PressureInsightsCopy.minEntriesForLoopLanguage,
  });

  final PressureLoopVisibility visibility;

  /// When true, only the basic free metrics are shown.
  final bool locked;

  /// Pro-only evidence confidence; shown only when provided and unlocked.
  final PressureEvidenceConfidence? confidence;

  /// Logged pressure moments — softer titles below
  /// [PressureInsightsCopy.minEntriesForLoopLanguage].
  final int entryCount;

  static const title = PressureInsightsCopy.visibilityCardTitleStrong;
  static const emptyBody =
      'No pressure moments logged yet. Noticing one is enough to start.';
  static const guiltFreeLine = 'No streak guilt — noticing once still counts.';

  @override
  Widget build(BuildContext context) {
    final lines = <Widget>[];

    if (!visibility.hasData) {
      lines.add(_line(context, emptyBody));
    } else {
      lines.add(
        _line(
          context,
          'You noticed pressure '
          '${_times(visibility.noticedThisWeek)} this week.',
        ),
      );
      lines.add(const SizedBox(height: AppSpacing.xs));
      lines.add(
        _line(
          context,
          visibility.choseToStopCount > 0
              ? 'You chose to stop ${_times(visibility.choseToStopCount)}.'
              : "You haven't logged a stop yet — and that's okay.",
        ),
      );
      // Strongest pressure + streak are part of the full (Pro) view only.
      if (!locked) {
        final strongest = visibility.strongestPhrase;
        if (strongest != null) {
          lines.add(const SizedBox(height: AppSpacing.xs));
          lines.add(_line(context, 'Showed up most: "$strongest".'));
        }
        if (visibility.streakDays > 0) {
          lines.add(const SizedBox(height: AppSpacing.xs));
          lines.add(
            _line(
              context,
              'Noticed-the-loop streak: '
              '${visibility.streakDays} '
              'day${visibility.streakDays == 1 ? '' : 's'}.',
            ),
          );
        }
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
            PressureInsightsCopy.visibilityCardTitle(entryCount),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          if (!locked && confidence != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: PressureConfidenceLabel(confidence: confidence!),
            ),
          ],
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
    style: ArchiveMobileTypography.body(
      context,
    ).copyWith(color: AppColors.textPrimary),
  );

  static String _times(int count) => '$count time${count == 1 ? '' : 's'}';
}
