import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Immediate post-save result after the user's first recording.
class FirstReflectionResultCard extends StatelessWidget {
  const FirstReflectionResultCard({
    super.key,
    required this.onRecordAnother,
    required this.onViewPatterns,
  });

  final VoidCallback onRecordAnother;
  final VoidCallback onViewPatterns;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.firstSignalSavedTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.firstSignalSavedBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ConsumerUiCopy.firstSignalSavedSecondary,
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
          SizedBox(height: gap + 4),
          FilledButton(
            onPressed: onRecordAnother,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              ConsumerUiCopy.postSaveRecordAnother,
              style: ArchiveMobileTypography.responsiveCta(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onViewPatterns,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppColors.accentPrimary,
            ),
            child: Text(
              ConsumerUiCopy.viewPatternsCta,
              style: ArchiveMobileTypography.responsiveBody(
                context,
                color: AppColors.accentPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
