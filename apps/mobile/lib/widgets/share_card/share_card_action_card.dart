import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/share_card/share_card_copy.dart';
import 'package:archiveme_mobile/features/share_card/share_card_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/share_card/share_card_preview_sheet.dart';
import 'package:flutter/material.dart';

/// Compact share card entry point on Patterns / Pattern detail.
class ShareCardActionCard extends StatelessWidget {
  const ShareCardActionCard({
    required this.model, required this.source, super.key,
  });

  final ShareCardModel model;
  final String source;

  @override
  Widget build(BuildContext context) {
    if (!model.canShare) return const SizedBox.shrink();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.4);
    final secondaryStyle = bodyStyle.copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('share_card_action_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF7F8FA),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ShareCardCopy.headline,
            key: const Key('share_card_action_headline'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            model.displayPatternLabel,
            key: const Key('share_card_action_pattern_label'),
            style: bodyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            model.relatedMomentsLine,
            key: const Key('share_card_action_related_moments'),
            style: secondaryStyle,
          ),
          if (model.hasChangeNoticed) ...[
            const SizedBox(height: 2),
            Text(
              ShareCardCopy.changeNoticedLine,
              key: const Key('share_card_action_change_noticed'),
              style: secondaryStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            ShareCardCopy.footer,
            key: const Key('share_card_action_footer'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('share_card_create_button'),
              onPressed: () => ShareCardPreviewSheet.show(
                context,
                model: model,
                source: source,
              ),
              child: const Text(ShareCardCopy.createShareCardCta),
            ),
          ),
        ],
      ),
    );
  }
}