import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/curated_memory_marker.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

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