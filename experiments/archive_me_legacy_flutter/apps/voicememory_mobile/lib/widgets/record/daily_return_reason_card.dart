import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/early_archive/daily_return_reason_copy.dart';
import '../../features/early_archive/daily_return_reason_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// One grounded reason to record today based on archive gaps.
class DailyReturnReasonCard extends StatelessWidget {
  const DailyReturnReasonCard({
    super.key,
    required this.reason,
    required this.showRecordCta,
    this.onRecord,
  });

  final DailyReturnReasonResult reason;
  final bool showRecordCta;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final promptStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('daily_return_reason_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF8FAF8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reason.title,
            key: const Key('daily_return_reason_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            reason.body,
            key: const Key('daily_return_reason_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            reason.prompt,
            key: const Key('daily_return_reason_prompt'),
            style: promptStyle,
          ),
          if (showRecordCta && onRecord != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('daily_return_reason_record_cta'),
                onPressed: onRecord,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(DailyReturnReasonCopy.recordCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
