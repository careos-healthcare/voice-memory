import 'package:flutter/material.dart';

import '../../features/archive_controls/archive_control_copy.dart';
import '../../features/archive_controls/archive_control_engine.dart';

/// Confirms and deletes one saved archive moment.
abstract final class ArchiveMomentDeleteActions {
  ArchiveMomentDeleteActions._();

  static Future<bool> confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ArchiveControlCopy.deleteDialogTitle),
        content: const Text(ArchiveControlCopy.deleteDialogBody),
        actions: [
          TextButton(
            key: const Key('archive_moment_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(ArchiveControlCopy.deleteDialogCancel),
          ),
          FilledButton(
            key: const Key('archive_moment_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(ArchiveControlCopy.deleteDialogConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static Future<ArchiveMomentDeleteResult?> deleteMoment({
    required BuildContext context,
    required String entryId,
    required String source,
  }) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return null;

    final result = await ArchiveControlEngine.deleteMoment(
      entryId: entryId,
      source: source,
    );
    if (!context.mounted) return result;

    if (result.deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ArchiveControlCopy.deleteSuccess)),
      );
    }
    return result;
  }
}
