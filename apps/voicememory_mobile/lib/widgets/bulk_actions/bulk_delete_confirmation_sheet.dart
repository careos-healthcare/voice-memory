import 'package:flutter/material.dart';

import '../../features/bulk_actions/bulk_archive_action.dart';
import '../../theme/app_colors.dart';

/// Confirmation before bulk delete. Returns true only when the user
/// explicitly confirms.
Future<bool> showBulkDeleteConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(BulkActionsCopy.deleteConfirmTitle),
      content: const Text(BulkActionsCopy.deleteConfirmBody),
      actions: [
        TextButton(
          key: const Key('bulk_delete_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(BulkActionsCopy.cancel),
        ),
        FilledButton(
          key: const Key('bulk_delete_confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(BulkActionsCopy.deleteConfirmButton),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Confirmation before bulk archive. Returns true only when the user
/// explicitly confirms.
Future<bool> showBulkArchiveConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(BulkActionsCopy.archiveConfirmTitle),
      content: const Text(BulkActionsCopy.archiveConfirmBody),
      actions: [
        TextButton(
          key: const Key('bulk_archive_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(BulkActionsCopy.cancel),
        ),
        FilledButton(
          key: const Key('bulk_archive_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(BulkActionsCopy.archiveConfirmButton),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
