import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class PostSaveClearerMomentBanner extends StatelessWidget {
  const PostSaveClearerMomentBanner({
    required this.prompt, required this.onRecordNext, super.key,
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
      decoration:
          VoiceMemoryCards.standard(
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
            Text(lead!, style: ArchiveMobileTypography.explanationBody(context))
          else
            Text(
              ConsumerUiCopy.postSaveInsightNeedsClearerLead,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(prompt, style: ArchiveMobileTypography.explanationBody(context)),
          SizedBox(height: gap),
          FilledButton(
            onPressed: onRecordNext,
            child: const Text(ConsumerUiCopy.postSaveRecordAnother),
          ),
        ],
      ),
    );
  }
}