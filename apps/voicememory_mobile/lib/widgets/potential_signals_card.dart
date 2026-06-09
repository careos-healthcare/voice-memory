import 'package:flutter/material.dart';

import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../product/consumer_copy_guard.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Post-save card: what ArchiveMe noticed today and early pattern hints.
class PotentialSignalsCard extends StatelessWidget {
  const PotentialSignalsCard({
    super.key,
    required this.signals,
    this.noticedToday,
    this.showPatternHint = false,
  });

  final List<String> signals;
  final String? noticedToday;
  final bool showPatternHint;

  @override
  Widget build(BuildContext context) {
    final noticed = ConsumerCopyGuard.userFacingObservation(noticedToday) ?? '';
    final items = signals
        .map((s) => ConsumerCopyGuard.userFacingObservation(s))
        .whereType<String>()
        .take(3)
        .toList();
    if (noticed.isEmpty && items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (noticed.isNotEmpty) ...[
            Text(
              ConsumerUiCopy.todayArchiveMeNoticed,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              noticed,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ],
          if (items.isNotEmpty) ...[
            if (noticed.isNotEmpty)
              SizedBox(height: ArchiveResponsiveLayout.gap(context)),
            Text(
              ConsumerUiCopy.possiblePatternForming,
              style: ArchiveMobileTypography.responsiveSectionTitle(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final s in items.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $s',
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
              ),
          ],
          if (showPatternHint) ...[
            const SizedBox(height: AppSpacing.sm),
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
