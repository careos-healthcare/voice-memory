import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// The emotional endpoint of the first session: confirm tomorrow's check is set.
class FirstLoopReadyCard extends StatelessWidget {
  const FirstLoopReadyCard({
    super.key,
    required this.question,
    required this.onDone,
    this.onRecordAnother,
  });

  final String question;
  final VoidCallback onDone;
  final VoidCallback? onRecordAnother;

  static const String title = 'Tomorrow\u2019s check is set';
  static const String body = 'Come back tomorrow and ArchiveMe will ask:';
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
              Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 22),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45),
          ),
          if (question.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              question,
              style: VoiceMemoryTypography.bodyStyle(
                color: AppColors.textPrimary,
              ).copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onDone,
              child: const Text(doneCta),
            ),
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
