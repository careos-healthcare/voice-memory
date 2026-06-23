import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/demo/demo_share_pack.dart';
import '../../features/demo/sample_archive_copy.dart';
import '../../features/share/archive_share_actions.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Explicit share/copy actions for the sample archive demo summary only.
class DemoSharePackCard extends StatelessWidget {
  const DemoSharePackCard({
    super.key,
    required this.pack,
  });

  final DemoSharePack pack;

  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);

  Future<void> _share(BuildContext context) async {
    await ArchiveShareActions.shareShareText(
      context,
      text: pack.plainText,
      subject: SampleArchiveCopy.demoShareSubject,
    );
  }

  Future<void> _copy(BuildContext context) async {
    await ArchiveShareActions.copyShareText(
      context,
      text: pack.plainText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shareEnabled = ArchiveShareActions.isShareable(pack.plainText);

    return Container(
      key: const Key('demo_share_pack_card'),
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
            SampleArchiveCopy.demoShareSubtitle,
            key: const Key('demo_share_pack_label'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SampleArchiveCopy.demoShareTitle,
            key: const Key('demo_share_pack_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '• ${SampleArchiveCopy.demoShareBulletOne}',
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SampleArchiveCopy.demoShareEvidenceMapRow(
              'Work',
              pack.workMomentCount,
            ),
            key: const Key('demo_share_pack_work_count'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('demo_share_pack_share_button'),
                  onPressed: shareEnabled ? () => _share(context) : null,
                  child: const Text(SampleArchiveCopy.demoShareShareButton),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  key: const Key('demo_share_pack_copy_button'),
                  onPressed: shareEnabled ? () => _copy(context) : null,
                  child: const Text(SampleArchiveCopy.demoShareCopyButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
