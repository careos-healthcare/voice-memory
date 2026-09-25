import 'package:flutter/material.dart';

/// Asks before an import is posted to the app backend.
///
/// Returns true when the person opts in to the upload, and false when they
/// keep the import on this device.
class CloudConsentModal {
  CloudConsentModal._();

  static const title = 'Upload these notes?';

  static const body =
      'The text of this import would be sent to the Thoughtprint app '
      'backend at /api/ledger/bulk-import so it can be stored with your '
      'account. Keeping the notes on this device does not upload them.';

  static Future<bool> ask(BuildContext context) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('cloud_consent_modal'),
          title: const Text(title),
          content: const Text(body),
          actions: [
            TextButton(
              key: const Key('cloud_consent_keep_local'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep on this device'),
            ),
            FilledButton(
              key: const Key('cloud_consent_upload'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
    return allowed ?? false;
  }
}
