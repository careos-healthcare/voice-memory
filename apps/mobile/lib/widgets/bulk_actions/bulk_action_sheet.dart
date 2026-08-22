import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/bulk_actions/bulk_archive_action.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Bottom sheet listing bulk actions for the current selection.
/// Returns the chosen action, or null when dismissed.
Future<BulkArchiveAction?> showBulkActionSheet(
  BuildContext context, {
  List<BulkArchiveAction> actions = BulkArchiveAction.values,
}) {
  return showModalBottomSheet<BulkArchiveAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => BulkActionSheet(actions: actions),
  );
}

class BulkActionSheet extends StatelessWidget {
  const BulkActionSheet({super.key, this.actions = BulkArchiveAction.values});

  final List<BulkArchiveAction> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          for (final action in actions)
            ListTile(
              key: Key('bulk_action_${action.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(_icon(action), size: 20),
              title: Text(
                action.label,
                style: ArchiveMobileTypography.listTitle(context).copyWith(
                  color: action == BulkArchiveAction.deleteSelected
                      ? AppColors.error
                      : null,
                ),
              ),
              onTap: () => Navigator.of(context).pop(action),
            ),
        ],
      ),
    );
  }

  IconData _icon(BulkArchiveAction action) => switch (action) {
    BulkArchiveAction.exportSelected => Icons.ios_share_outlined,
    BulkArchiveAction.addToCollection => Icons.bookmark_add_outlined,
    BulkArchiveAction.pinSelected => Icons.push_pin_outlined,
    BulkArchiveAction.unpinSelected => Icons.push_pin,
    BulkArchiveAction.archiveSelected => Icons.archive_outlined,
    BulkArchiveAction.deleteSelected => Icons.delete_outline,
    BulkArchiveAction.treatAsNew => Icons.fiber_new_outlined,
    BulkArchiveAction.keepExactDetails => Icons.format_quote_outlined,
  };
}