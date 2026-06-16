import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Small success confirmation shown after a quick pressure check-in save.
class PressureQuickSaveSuccess extends StatelessWidget {
  const PressureQuickSaveSuccess({super.key});

  static const message = 'Logged. Your archive has one more piece of evidence.';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pressure_quick_save_success'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(background: const Color(0xFFEFF7F0)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: ArchiveMobileTypography.body(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
