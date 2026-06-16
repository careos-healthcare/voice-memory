import 'package:flutter/material.dart';

import '../../security/private_data_service.dart';
import '../../security/security_settings_copy.dart';
import '../../services/app_services.dart';
import '../../theme/app_colors.dart';

/// Double-confirmation dialog for wiping all local archive data.
/// Does not require app-lock PIN — intended for emergency delete paths.
Future<bool> showWipeLocalArchiveDialog(BuildContext context) async {
  final controller = TextEditingController();
  var confirmed = false;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text(SecuritySettingsCopy.wipeConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(SecuritySettingsCopy.wipeConfirmBody),
          const SizedBox(height: 16),
          TextField(
            key: const Key('wipe_archive_confirm_field'),
            controller: controller,
            decoration: const InputDecoration(
              labelText: SecuritySettingsCopy.wipeConfirmHint,
              border: OutlineInputBorder(),
            ),
            autocorrect: false,
            enableSuggestions: false,
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('wipe_archive_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('wipe_archive_confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            if (controller.text.trim() ==
                PrivateDataService.wipeConfirmationPhrase) {
              confirmed = true;
              Navigator.of(dialogContext).pop(true);
            }
          },
          child: const Text('Delete local data'),
        ),
      ],
    ),
  );

  controller.dispose();
  if (result != true || !confirmed) return false;

  final service = PrivateDataService(
    journalStore: AppServices.instance.journalStore,
    prefs: AppServices.instance.prefs,
  );
  await service.wipeAllLocalArchive(
    confirmationPhrase: PrivateDataService.wipeConfirmationPhrase,
  );
  return true;
}
