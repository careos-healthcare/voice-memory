import 'package:archiveme_mobile/core/services/rich_import_permission_client.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/rich_import_copy.dart';
import 'package:flutter/material.dart';

/// In-app explanation shown before any camera, photo, or location dialog.
abstract final class SoftPermissionOverlay {
  static Future<bool> show(BuildContext context, SoftPermissionKind kind) {
    final title = switch (kind) {
      SoftPermissionKind.photos => RichImportCopy.photoSoftTitle,
      SoftPermissionKind.location => RichImportCopy.locationSoftTitle,
    };
    final body = switch (kind) {
      SoftPermissionKind.photos => RichImportCopy.photoSoftBody,
      SoftPermissionKind.location => RichImportCopy.locationSoftBody,
    };
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('soft_permission_overlay'),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              key: const Key('soft_permission_not_now'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(RichImportCopy.notNow),
            ),
            FilledButton(
              key: const Key('soft_permission_continue'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(RichImportCopy.continueLabel),
            ),
          ],
        );
      },
    ).then((allowed) => allowed ?? false);
  }
}

/// Explains a declined or unavailable permission without a second system sheet.
abstract final class RichImportFailureOverlay {
  static Future<void> show(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('rich_import_failure_overlay'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
