import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

class PostSaveClearerMomentBanner extends StatelessWidget {
  const PostSaveClearerMomentBanner({
    required this.prompt,
    required this.onRecordNext,
    this.title,
    this.lead,
  });

  final String prompt;
  final VoidCallback onRecordNext;
  final String? title;
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.accentPrimary.withValues(alpha: 0.06),
      ).copyWith(
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title ?? ConsumerUiCopy.postSaveInsightNeedsClearerMoment,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: gap / 2),
          if (lead != null && lead!.isNotEmpty)
            Text(
              lead!,
              style: ArchiveMobileTypography.explanationBody(context),
            )
          else
            Text(
              ConsumerUiCopy.postSaveInsightNeedsClearerLead,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            prompt,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: gap),
          FilledButton(
            onPressed: onRecordNext,
            child: Text(ConsumerUiCopy.postSaveRecordAnother),
          ),
        ],
      ),
    );
  }
}
