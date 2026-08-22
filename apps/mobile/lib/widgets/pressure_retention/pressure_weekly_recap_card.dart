import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_insights_copy.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_weekly_recap_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// "Weekly pressure recap" card built from local entries in the last 7 days.
///
/// Free users see a limited preview (count + chose-to-stop, with the deeper
/// "where it repeats" insight locked). Pro users see the full recap.
class PressureWeeklyRecapCard extends StatelessWidget {
  const PressureWeeklyRecapCard({
    required this.recap, super.key,
    this.locked = false,
    this.entryCount = PressureInsightsCopy.minEntriesForLoopLanguage,
  });

  final PressureWeeklyRecap recap;

  /// When true, the deeper insight (most common context/option) is locked.
  final bool locked;

  /// Logged pressure moments — softer titles below
  /// [PressureInsightsCopy.minEntriesForLoopLanguage].
  final int entryCount;

  static const String title = PressureInsightsCopy.weeklyRecapTitleStrong;
  static const previewMoreCopy =
      'Your archive has more to say about where this repeats.';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_weekly_recap_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFDF8F3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PressureInsightsCopy.weeklyRecapTitle(entryCount),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (locked) ..._lockedBody(context) else ..._fullBody(context),
        ],
      ),
    );
  }

  List<Widget> _fullBody(BuildContext context) {
    return [
      Text(
        recap.sentence,
        style: ArchiveMobileTypography.body(
          context,
        ).copyWith(color: AppColors.textPrimary),
      ),
      if (recap.hasData) ...[
        const SizedBox(height: AppSpacing.md),
        _row(context, 'Pressure moments', '${recap.count}'),
        if (recap.mostCommonOptionLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _row(context, 'Most common', recap.mostCommonOptionLabel!),
        ],
        if (recap.mostCommonContextLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _row(context, 'Most common context', recap.mostCommonContextLabel!),
        ],
        const SizedBox(height: AppSpacing.xs),
        _row(context, 'Chose to stop', '${recap.choseToStopCount}'),
      ],
    ];
  }

  List<Widget> _lockedBody(BuildContext context) {
    if (!recap.hasData) {
      return [
        Text(
          recap.sentence,
          style: ArchiveMobileTypography.body(
            context,
          ).copyWith(color: AppColors.textPrimary),
        ),
      ];
    }
    return [
      _row(context, 'Pressure moments this week', '${recap.count}'),
      const SizedBox(height: AppSpacing.xs),
      _row(context, 'Chose to stop', '${recap.choseToStopCount}'),
      const SizedBox(height: AppSpacing.xs),
      Row(
        children: [
          const Icon(
            Icons.lock_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Most common context',
              style: ArchiveMobileTypography.cardLabel(context),
            ),
          ),
          Text(
            '•••••',
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textSecondary, letterSpacing: 2),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        previewMoreCopy,
        style: ArchiveMobileTypography.body(
          context,
        ).copyWith(color: AppColors.accentPrimary, fontWeight: FontWeight.w600),
      ),
    ];
  }

  Widget _row(BuildContext context, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: ArchiveMobileTypography.cardLabel(context)),
      ),
      const SizedBox(width: AppSpacing.sm),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: ArchiveMobileTypography.body(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}