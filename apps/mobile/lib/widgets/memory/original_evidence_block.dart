import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/memory/curated_memory_marker.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Privacy-safe original-evidence section for evidence inspection.
class OriginalEvidenceBlock extends StatelessWidget {
  const OriginalEvidenceBlock({super.key, this.showDetailLine = true});

  final bool showDetailLine;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('original_evidence_block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          CuratedMemoryCopy.originalEvidenceSectionTitle,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (showDetailLine)
          Text(
            CuratedMemoryCopy.originalSavedDetail,
            style: ArchiveMobileTypography.responsiveHelper(
              context,
            ).copyWith(color: AppColors.textSecondary),
          ),
      ],
    );
  }
}