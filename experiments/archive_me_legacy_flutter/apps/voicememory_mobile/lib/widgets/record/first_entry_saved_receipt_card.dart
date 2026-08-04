import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/voice_capture/voice_capture_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Compact confirmation after the very first save — Done / Record another
/// live in the bottom CTA bar; this card is receipt copy only.
class FirstEntrySavedReceiptCard extends StatelessWidget {
  const FirstEntrySavedReceiptCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('first_entry_saved_receipt_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            VoiceCaptureCopy.recordingSavedTitle,
            key: const Key('first_entry_saved_receipt_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            VoiceCaptureCopy.firstSaveReceiptNote,
            key: const Key('first_entry_saved_receipt_body'),
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textPrimary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
