import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/moment_quality/moment_quality_feedback_engine.dart';
import '../../models/journal_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Gentle post-save guidance on whether a moment can be compared later.
class MomentQualityFeedbackCard extends StatelessWidget {
  const MomentQualityFeedbackCard({super.key, required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final result = MomentQualityFeedbackEngine.build(entry: entry);
    if (result == null) {
      return const SizedBox.shrink(key: Key('moment_quality_feedback_hidden'));
    }

    final titleStyle = ArchiveMobileTypography.cardLabel(
      context,
    ).copyWith(fontWeight: FontWeight.w600);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        key: Key('moment_quality_feedback_card_${result.kind.name}'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: const Color(0xFFFAFAF8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.title,
              key: Key('moment_quality_feedback_title_${result.kind.name}'),
              style: titleStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              result.body,
              key: Key('moment_quality_feedback_body_${result.kind.name}'),
              style: bodyStyle,
            ),
          ],
        ),
      ),
    );
  }
}
