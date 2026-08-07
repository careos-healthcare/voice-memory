import 'package:flutter/material.dart';

import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// First-run framing shown before any moment is saved: get the user to record
/// one moment so the loop can start.
class FirstLoopStartCard extends StatelessWidget {
  const FirstLoopStartCard({
    super.key,
    required this.onRecord,
    this.showRecordCta = true,
  });

  final VoidCallback onRecord;
  final bool showRecordCta;

  static const String title = 'Start with one moment';
  static const String body = 'Say what happened today. One sentence is enough.';
  static const String cta = 'Record one moment';

  static const List<String> examples = [
    'I said yes before checking what I needed.',
    'The same worry came back when things got quiet.',
    'I avoided the message because I did not want pressure.',
  ];

  static const Color _warmSurface = Color(0xFFFFFBF5);
  static const Color _warmBorder = AppColors.warmBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _warmSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VoiceMemoryTypography.cardTitleStyle().copyWith(
              fontSize: 18,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in examples) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textSecondary,
                    ).copyWith(fontSize: 14, height: 1.45),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: AppColors.textSecondary,
                      ).copyWith(fontSize: 14, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            ConsumerUiCopy.firstRecordPositioningLine,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 13, height: 1.4),
          ),
          if (showRecordCta) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(onPressed: onRecord, child: const Text(cta)),
            ),
          ],
        ],
      ),
    );
  }
}
