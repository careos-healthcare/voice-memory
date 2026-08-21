import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:archiveme_mobile/product/consumer_copy_guard.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Surfaces what ArchiveMe noticed today after a successful save.
class TodayNoticedPostSaveCard extends StatelessWidget {
  const TodayNoticedPostSaveCard({
    required this.loop, super.key,
    this.showPossiblePattern = false,
  });

  final TomorrowReturnLoop loop;
  final bool showPossiblePattern;

  @override
  Widget build(BuildContext context) {
    final noticed = loop.noticedToday.trim();
    if (noticed.isEmpty || ConsumerCopyGuard.isSystemObservation(noticed)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.todayArchiveMeNoticed,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            noticed,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          if (showPossiblePattern) ...[
            SizedBox(height: ArchiveResponsiveLayout.gap(context)),
            Text(
              ConsumerUiCopy.possiblePatternForming,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ConsumerUiCopy.ifShowsUpAgainPattern,
              style: ArchiveMobileTypography.responsiveBody(context),
            ),
          ],
        ],
      ),
    );
  }
}