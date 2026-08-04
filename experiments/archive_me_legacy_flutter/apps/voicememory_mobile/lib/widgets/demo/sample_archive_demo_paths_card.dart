import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/demo/sample_archive_copy.dart';
import '../../features/demo/sample_archive_demo_paths.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Quick demo path rows — Sample Archive only, example data never persisted.
class SampleArchiveDemoPathsCard extends StatelessWidget {
  const SampleArchiveDemoPathsCard({
    super.key,
    required this.scrollController,
    required this.evidenceMapKey,
  });

  final ScrollController scrollController;
  final GlobalKey evidenceMapKey;

  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);

  Future<void> _onPathTap(BuildContext context, String pathId) {
    return SampleArchiveDemoPaths.runPath(
      context,
      pathId: pathId,
      scrollController: scrollController,
      evidenceMapKey: evidenceMapKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sample_archive_demo_paths_card'),
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
            SampleArchiveCopy.demoPathsTitle,
            key: const Key('sample_archive_demo_paths_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SampleArchiveCopy.demoPathsIntro,
            key: const Key('sample_archive_demo_paths_intro'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final path in SampleArchiveDemoPaths.paths) ...[
            _DemoPathRow(path: path, onTap: () => _onPathTap(context, path.id)),
            if (path.id != SampleArchiveDemoPaths.paths.last.id)
              const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            SampleArchiveCopy.demoPathsFooterOne,
            key: const Key('sample_archive_demo_paths_footer_one'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SampleArchiveCopy.demoPathsFooterTwo,
            key: const Key('sample_archive_demo_paths_footer_two'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
      ),
    );
  }
}

class _DemoPathRow extends StatelessWidget {
  const _DemoPathRow({required this.path, required this.onTap});

  final SampleArchiveDemoPath path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SampleArchiveDemoPathsCard._border),
      ),
      child: InkWell(
        key: path.buttonKey,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  path.title,
                  key: Key('sample_archive_demo_path_label_${path.id}'),
                  style: ArchiveMobileTypography.listTitle(context),
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
    );
  }
}
