import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/security/archive_privacy_controls_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/widgets/security/archive_data_flow_sheet.dart';
import 'package:archiveme_mobile/widgets/security/wipe_local_archive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    // `ListTile` paints its ink splash on the nearest `Material` *ancestor*, and
    // the card above wraps these rows in a `DecoratedBox` (from its `Container`
    // decoration) that has an opaque background. Without a `Material` between
    // the two, every tap ripple painted behind that background and was never
    // seen — and `ListTile` asserts about exactly this whenever `onTap` is set.
    // A transparency `Material` paints nothing at rest, so the card keeps its
    // own background, border, and radius while the rows get a surface to splash
    // on. `tileColor` is not the fix: it would put the colour on the row rather
    // than the card, and it makes the assert fire on untappable rows too.
    return Material(
      type: MaterialType.transparency,
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
