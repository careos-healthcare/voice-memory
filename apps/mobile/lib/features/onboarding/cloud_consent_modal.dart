import 'dart:async';

import 'package:archiveme_mobile/features/onboarding/cloud_consent.dart';
import 'package:flutter/material.dart';

/// Asks before journal text is uploaded for cloud features.
///
/// Returns true when the person opts in, and false when they keep the import
/// on this device.
class CloudConsentModal {
  CloudConsentModal._();

  static const title = 'Upload these notes?';

  static const what = 'The text of your entries is sent.';

  static const why =
      'So pattern exploration can remember across weeks.';

  static const where =
      "It is kept on Thoughtprint's servers. Answers are written by Google Gemini.";

  static const control =
      'You can delete that copy in Settings. The journal on this phone stays.';

  static Future<bool> ask(BuildContext context) async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('cloud_consent_modal'),
          title: const Text(title),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(what),
              SizedBox(height: 12),
              Text(why),
              SizedBox(height: 12),
              Text(where),
              SizedBox(height: 12),
              Text(control),
            ],
          ),
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
    if (allowed == true && context.mounted) {
      await enableCloudWithProgress(context);
    }
    return allowed ?? false;
  }
}

/// Sends existing entries after opt-in and shows how far the copy has got.
Future<void> enableCloudWithProgress(BuildContext context) async {
  final progress = ValueNotifier<(int, int)>((0, 0));
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (context, value, _) {
            final total = value.$2;
            return AlertDialog(
              key: const Key('cloud_backfill_progress'),
              title: const Text('Sending your journal'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: total == 0 ? null : value.$1 / total,
                  ),
                  const SizedBox(height: 12),
                  Text('${value.$1} of $total'),
                ],
              ),
            );
          },
        );
      },
    ),
  );
  try {
    await CloudConsent().enable(
      onProgress: (done, total) {
        progress.value = (done, total);
      },
    );
  } finally {
    progress.dispose();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
