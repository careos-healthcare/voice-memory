import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/moment_quality/moment_quality_feedback_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

/// Gentle post-save guidance on whether a moment can be compared later.
class MomentQualityFeedbackCard extends StatelessWidget {
  const MomentQualityFeedbackCard({required this.entry, super.key});

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