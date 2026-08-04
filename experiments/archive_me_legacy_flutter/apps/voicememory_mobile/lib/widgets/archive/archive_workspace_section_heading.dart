import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Section heading for grouped Archive/Patterns workspace cards.
class ArchiveWorkspaceSectionHeading extends StatelessWidget {
  const ArchiveWorkspaceSectionHeading({
    super.key,
    required this.sectionId,
    required this.title,
  });

  final String sectionId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        key: Key('archive_workspace_section_$sectionId'),
        style: ArchiveMobileTypography.responsiveSectionTitle(
          context,
        ).copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
