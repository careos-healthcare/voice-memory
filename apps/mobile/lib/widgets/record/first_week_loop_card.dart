import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/early_archive/first_week_loop_analytics.dart';
import 'package:archiveme_mobile/features/early_archive/first_week_loop_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// First-week return loop — subtle secondary record CTA only when safe.
class FirstWeekLoopCard extends StatelessWidget {
  const FirstWeekLoopCard({
    required this.loop, required this.entryCount, super.key,
    this.showRecordCta = true,
    this.onRecord,
  });

  final FirstWeekLoop loop;
  final int entryCount;
  final bool showRecordCta;
  final VoidCallback? onRecord;

  void _trackSeen() {
    FirstWeekLoopAnalytics.seen(
      entryCount: entryCount,
      hasPhrase: loop.hasPhrase,
      hasConfirmedRepeat: loop.hasConfirmedRepeat,
    );
  }

  void _trackRecordTapped() {
    FirstWeekLoopAnalytics.recordTapped(
      entryCount: entryCount,
      hasPhrase: loop.hasPhrase,
      hasConfirmedRepeat: loop.hasConfirmedRepeat,
    );
  }

  @override
  Widget build(BuildContext context) {
    _trackSeen();
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('first_week_loop_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loop.label,
            key: const Key('first_week_loop_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            loop.title,
            key: const Key('first_week_loop_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            loop.body,
            key: const Key('first_week_loop_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loop.footer,
            key: const Key('first_week_loop_footer'),
            style: bodyStyle.copyWith(fontSize: 13),
          ),
          if (showRecordCta && onRecord != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('first_week_loop_record_cta'),
                onPressed: () {
                  _trackRecordTapped();
                  onRecord!();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(loop.cta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}