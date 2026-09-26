import 'dart:async';

import 'package:archiveme_mobile/core/user/user_preferences.dart';
import 'package:archiveme_mobile/features/sync/services/cloud_sync_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Asks before journal text is uploaded for cloud features.
///
/// Returns true when the person opts in, and false when they keep the import
/// on this device.
class CloudConsentModal {
  CloudConsentModal._();

  static const title = 'Upload these notes?';

  static const what = 'The text of your journal entries will be uploaded.';

  static const why =
      'To power AI Pattern Exploration so you can ask questions about your journal.';

  static const where =
      "Processed securely by Google Gemini on Thoughtprint's servers.";

  static const control =
      'You can turn this off and delete your cloud copy at any time in Settings.';

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
    if (allowed == true) {
      if (AppServices.isInitialized) {
        await UserPreferences.setCloudSyncEnabled(
          AppServices.instance.prefs,
          true,
        );
      }
      unawaited(CloudSyncService.backfillLocalEntries());
    }
    return allowed ?? false;
  }
}
