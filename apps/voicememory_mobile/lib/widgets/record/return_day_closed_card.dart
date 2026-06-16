import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Compact return-day payoff: the loop is closed in seconds, so the screen does
/// not bury the user under a wall of cards.
class ReturnDayClosedCard extends StatelessWidget {
  const ReturnDayClosedCard({
    super.key,
    required this.resultHeadline,
    required this.usefulLine,
    required this.nextCheck,
    required this.onDone,
    this.onRecordAnother,
  });

  final String resultHeadline;
  final String usefulLine;
  final String nextCheck;
  final VoidCallback onDone;
  final VoidCallback? onRecordAnother;

  static const String title = 'Loop closed';
  static const String nextLabel = 'Next check:';
  static const String doneCta = 'Done for today';
  static const String recordAnotherCta = 'Record another moment';

  static const Color _surface = Color(0xFFEFF6EF);
  static const Color _border = Color(0xFFD6E8D6);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                    fontSize: 17,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          if (resultHeadline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              resultHeadline,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ],
          if (usefulLine.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              usefulLine,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(height: 1.45),
            ),
          ],
          if (nextCheck.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              nextLabel,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textSecondary,
              ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              nextCheck,
              style:
                  VoiceMemoryTypography.bodyStyle(
                    color: AppColors.textPrimary,
                  ).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(onPressed: onDone, child: const Text(doneCta)),
          ),
          if (onRecordAnother != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: onRecordAnother,
                child: const Text(recordAnotherCta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
