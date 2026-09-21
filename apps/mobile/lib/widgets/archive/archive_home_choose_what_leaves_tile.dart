import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive/ui/remote_processing_choice_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Second settings entry on Archive Home — does not replace Account → Settings.
class ArchiveHomeChooseWhatLeavesTile extends StatelessWidget {
  const ArchiveHomeChooseWhatLeavesTile({required this.onTap, super.key});

  static const Key tileKey = Key('archive_home_choose_what_leaves_tile');

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${RemoteProcessingChoiceCopy.chooseWhatLeavesTitle}. '
          '${RemoteProcessingChoiceCopy.whereWordsGoSubtitle}',
      child: Material(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          key: tileKey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          title: Text(
            RemoteProcessingChoiceCopy.chooseWhatLeavesTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          subtitle: Text(
            RemoteProcessingChoiceCopy.whereWordsGoSubtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
