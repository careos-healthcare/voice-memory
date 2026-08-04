import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/production_navigation.dart';
import '../../design/archive_mobile_typography.dart';
import '../../security/archive_privacy_controls_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import 'archive_data_flow_sheet.dart';
import 'wipe_local_archive_dialog.dart';

/// User-visible trust controls — lock, export, delete, and data-flow transparency.
class ArchivePrivacyControlsCard extends StatelessWidget {
  const ArchivePrivacyControlsCard({
    super.key,
    this.onLockTap,
    this.onExportTap,
    this.onDeleteTap,
    this.onCloudTap,
    this.deleteBusy = false,
  });

  final VoidCallback? onLockTap;
  final VoidCallback? onExportTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onCloudTap;
  final bool deleteBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('archive_privacy_controls_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.flat(
        background: AppColors.backgroundSecondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchivePrivacyControlsCopy.cardTitle,
            key: const Key('archive_privacy_controls_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(
            context,
            key: const Key('archive_privacy_lock_row'),
            title: ArchivePrivacyControlsCopy.lockTitle,
            subtitle: ArchivePrivacyControlsCopy.lockSubtitle,
            onTap: onLockTap ?? () => context.push('/security'),
          ),
          if (ProductionNavigation.isNavRouteVisible('/export'))
            _row(
              context,
              key: const Key('archive_privacy_export_row'),
              title: ArchivePrivacyControlsCopy.exportTitle,
              subtitle: ArchivePrivacyControlsCopy.exportSubtitle,
              onTap: onExportTap ?? () => context.push('/export'),
            ),
          _row(
            context,
            key: const Key('archive_privacy_delete_row'),
            title: ArchivePrivacyControlsCopy.deleteTitle,
            subtitle: ArchivePrivacyControlsCopy.deleteSubtitle,
            destructive: true,
            onTap: deleteBusy
                ? null
                : onDeleteTap ??
                      () async {
                        await showWipeLocalArchiveDialog(context);
                      },
          ),
          _row(
            context,
            key: const Key('archive_privacy_cloud_row'),
            title: ArchivePrivacyControlsCopy.cloudTitle,
            subtitle: ArchivePrivacyControlsCopy.cloudSubtitle,
            onTap: onCloudTap ?? () => showArchiveDataFlowSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required Key key,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool destructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: ArchiveMobileTypography.listTitle(context).copyWith(
            color: destructive ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
