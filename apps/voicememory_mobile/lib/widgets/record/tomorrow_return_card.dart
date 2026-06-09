import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/tomorrow_return/tomorrow_return_loop_models.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save card inviting a return tomorrow — compact, no filler chips.
class TomorrowReturnCard extends StatelessWidget {
  const TomorrowReturnCard({
    super.key,
    required this.loop,
  });

  final TomorrowReturnLoop loop; // retained for call-site compatibility

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
            ConsumerUiCopy.oneMoreReflectionMakesClearer,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.tomorrowComparePatternsBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: gap + 4),
          FilledButton(
            onPressed: () => context.go('/archive-belief'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              ConsumerUiCopy.viewPatternsCta,
              style: ArchiveMobileTypography.responsiveCta(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go('/record'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              ConsumerUiCopy.postSaveRecordAnother,
              style: ArchiveMobileTypography.responsiveBody(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
