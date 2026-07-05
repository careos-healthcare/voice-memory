import 'package:flutter/material.dart';

import '../../features/archive_controls/archive_control_copy.dart';
import '../../features/archive_controls/archive_exclusion_engine.dart';

/// Confirms and excludes one moment from one pattern's evidence.
abstract final class ArchivePatternExclusionActions {
  ArchivePatternExclusionActions._();

  static Future<bool> confirmExclude(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(ArchiveControlCopy.excludeDialogTitle),
        content: const Text(ArchiveControlCopy.excludeDialogBody),
        actions: [
          TextButton(
            key: const Key('archive_pattern_exclude_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(ArchiveControlCopy.deleteDialogCancel),
          ),
          FilledButton(
            key: const Key('archive_pattern_exclude_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(ArchiveControlCopy.excludeDialogConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  static Future<ArchivePatternExclusionResult?> excludeFromPattern({
    required BuildContext context,
    required String entryId,
    required String patternKey,
    required String source,
  }) async {
    final confirmed = await confirmExclude(context);
    if (!confirmed || !context.mounted) return null;

    final result = await ArchiveExclusionEngine.excludeFromPattern(
      entryId: entryId,
      patternKey: patternKey,
      source: source,
    );
    if (!context.mounted) return result;

    if (result.excluded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ArchiveControlCopy.excludeSuccess)),
      );
    }
    return result;
  }
}
