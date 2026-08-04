import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/curated_memory_marker.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Post-save receipt when Preserve original was selected.
class CuratedMemoryReceipt extends StatelessWidget {
  const CuratedMemoryReceipt({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('curated_memory_receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: VoiceMemoryCards.flat(background: AppColors.surfaceAlt),
      child: Text(
        CuratedMemoryCopy.savedReceipt,
        style: ArchiveMobileTypography.cardLabel(context),
      ),
    );
  }
}
