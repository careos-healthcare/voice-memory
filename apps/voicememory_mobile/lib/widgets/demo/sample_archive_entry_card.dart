import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/demo/sample_archive_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Zero-entry Archive/Patterns link into the optional sample archive.
class SampleArchiveEntryCard extends StatelessWidget {
  const SampleArchiveEntryCard({
    super.key,
    required this.onViewSample,
  });

  final VoidCallback onViewSample;

  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Material(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        child: InkWell(
          key: const Key('sample_archive_entry_card'),
          borderRadius: BorderRadius.circular(16),
          onTap: onViewSample,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SampleArchiveCopy.emptyStateTitle,
                        key: const Key('sample_archive_entry_title'),
                        style: ArchiveMobileTypography.listTitle(context),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        SampleArchiveCopy.emptyStateSubtitle,
                        key: const Key('sample_archive_entry_subtitle'),
                        style: ArchiveMobileTypography.listSubtitle(context),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
