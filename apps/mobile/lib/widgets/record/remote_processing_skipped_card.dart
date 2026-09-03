import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive/ui/remote_processing_choice_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shown when remote processing is off, in place of a silent omit of the
/// reflection/analysis card.
class RemoteProcessingSkippedCard extends StatelessWidget {
  const RemoteProcessingSkippedCard({super.key, this.onChooseWhatLeaves});

  static const Key cardKey = Key('remote_processing_skipped_card');
  static const Key bodyKey = Key('remote_processing_skipped_body');
  static const Key ctaKey = Key('remote_processing_skipped_cta');

  final VoidCallback? onChooseWhatLeaves;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: cardKey,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RemoteProcessingChoiceCopy.skippedNote,
            key: bodyKey,
            style: bodyStyle,
          ),
          if (onChooseWhatLeaves != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ctaKey,
                onPressed: onChooseWhatLeaves,
                child: const Text(
                  RemoteProcessingChoiceCopy.chooseWhatLeavesTitle,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
