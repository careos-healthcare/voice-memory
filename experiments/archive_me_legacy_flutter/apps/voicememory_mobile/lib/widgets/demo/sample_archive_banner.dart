import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/demo/sample_archive_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Top-of-screen label so sample data is never confused with a private archive.
class SampleArchiveBanner extends StatelessWidget {
  const SampleArchiveBanner({super.key});

  static const Color _surface = Color(0xFFF4F8FF);
  static const Color _border = Color(0xFFD6E4FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sample_archive_banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SampleArchiveCopy.bannerTitle,
            key: const Key('sample_archive_banner_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SampleArchiveCopy.bannerSubtitle,
            key: const Key('sample_archive_banner_subtitle'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SampleArchiveCopy.themeLabel,
            key: const Key('sample_archive_theme_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
