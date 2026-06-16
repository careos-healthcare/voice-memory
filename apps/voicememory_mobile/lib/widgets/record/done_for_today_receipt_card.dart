import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../features/pressure_retention/done_for_today_receipt_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact post-save closure card: done for today, what was added, and one
/// calm reason to come back tomorrow. No new prompt choices, no Pro gate.
class DoneForTodayReceiptCard extends StatelessWidget {
  const DoneForTodayReceiptCard({super.key, required this.receipt});

  final DoneForTodayReceipt receipt;

  @override
  Widget build(BuildContext context) {
    if (!receipt.hasReceipt) return const SizedBox.shrink();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.doneForTodaySeen,
      hasConnectedThread: receipt.sourceTerms.isNotEmpty,
      oncePerSession: true,
    );

    return Container(
      key: const Key('done_for_today_receipt_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF3F8F5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  receipt.title,
                  style: ArchiveMobileTypography.responsiveSectionTitle(
                    context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _line(context, receipt.completionLine, primary: true),
          _line(context, receipt.archiveLine, primary: true),
          _line(context, receipt.tomorrowLine),
          _line(context, receipt.restLine),
          if (receipt.tomorrowCueLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              receipt.tomorrowCueTitle,
              key: const Key('done_for_today_tomorrow_cue_title'),
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            _line(context, receipt.tomorrowCueLine, primary: true),
            _line(context, DoneForTodayReceipt.tomorrowCueAutonomyLine),
          ],
          if (receipt.sourceTerms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('done_for_today_view_plan_cta'),
                  onPressed: () => context.push('/pressure-insights'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text(DoneForTodayReceipt.viewThreadPlanLabel),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text, {bool primary = false}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: primary ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
