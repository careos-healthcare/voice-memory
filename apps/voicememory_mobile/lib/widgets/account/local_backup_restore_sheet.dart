import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/local_backup/local_backup_copy.dart';
import '../../features/local_backup/local_backup_restore_service.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';

Future<bool> showExportLocalBackupDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text(LocalBackupCopy.exportTitle),
      content: const Text(LocalBackupCopy.exportBody),
      actions: [
        TextButton(
          key: const Key('local_backup_export_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(LocalBackupCopy.cancel),
        ),
        FilledButton(
          key: const Key('local_backup_export_confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(LocalBackupCopy.exportPrimary),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> showRestoreLocalBackupDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text(LocalBackupCopy.restoreTitle),
      content: const Text(LocalBackupCopy.restoreBody),
      actions: [
        TextButton(
          key: const Key('local_backup_restore_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(LocalBackupCopy.cancel),
        ),
        FilledButton(
          key: const Key('local_backup_restore_confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(LocalBackupCopy.restorePrimary),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> runExportLocalBackupFlow(
  BuildContext context, {
  required LocalBackupRestoreService service,
  required String source,
  required VoidCallback onComplete,
}) async {
  if (!AppServices.isInitialized) return;
  final confirmed = await showExportLocalBackupDialog(context);
  if (!confirmed || !context.mounted) return;

  final result = await service.exportBackup(source: source);
  if (!context.mounted) return;

  if (result.succeeded) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(LocalBackupCopy.exportSuccess)),
    );
  }
  onComplete();
}

Future<void> runRestoreLocalBackupFlow(
  BuildContext context, {
  required LocalBackupRestoreService service,
  required String source,
  required VoidCallback onComplete,
}) async {
  if (!AppServices.isInitialized) return;

  final pickResult = await service.pickAndRestoreBackup(source: source);
  if (!context.mounted) return;

  if (pickResult.cancelled) return;

  if (pickResult.failure == LocalBackupRestoreFailure.invalidBackup) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LocalBackupCopy.invalidBackup,
          style: ArchiveMobileTypography.listTitle(context),
        ),
      ),
    );
    return;
  }

  if (!pickResult.succeeded) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(LocalBackupCopy.restoreSuccess)),
  );
  onComplete();
}

/// Privacy centre restore flow with explicit confirmation before replace.
Future<void> runRestoreLocalBackupFlowWithConfirmation(
  BuildContext context, {
  required LocalBackupRestoreService service,
  required String source,
  required Future<String?> Function() pickBackupFile,
  required VoidCallback onComplete,
}) async {
  if (!AppServices.isInitialized) return;

  final raw = await pickBackupFile();
  if (raw == null || !context.mounted) return;

  final confirmed = await showRestoreLocalBackupDialog(context);
  if (!confirmed || !context.mounted) return;

  final result = await service.restoreBackup(source: source, rawJson: raw);
  if (!context.mounted) return;

  if (result.failure == LocalBackupRestoreFailure.invalidBackup) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocalBackupCopy.invalidBackup)),
    );
    return;
  }

  if (!result.succeeded) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(LocalBackupCopy.restoreSuccess)),
  );
  onComplete();
}
