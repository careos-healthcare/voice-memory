import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Section heading for grouped Archive/Patterns workspace cards.
class ArchiveWorkspaceSectionHeading extends StatelessWidget {
  const ArchiveWorkspaceSectionHeading({
    required this.sectionId, required this.title, super.key,
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