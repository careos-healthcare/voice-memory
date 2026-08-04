import 'package:flutter/material.dart';

import '../../features/disaster_recovery/disaster_recovery_core.dart';
import '../../features/disaster_recovery/disaster_recovery_service.dart';
import '../../theme/app_colors.dart';

Future<String?> showRecoveryPassphraseDialog(
  BuildContext context, {
  required bool importing,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        importing
            ? 'Restore encrypted recovery archive'
            : 'Create encrypted recovery archive',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            importing
                ? 'Import replaces local journal, preferences, and pending '
                      'transcriptions. The current data is restored if import fails.'
                : 'Choose a passphrase you can store safely. Forgotten '
                      'passphrases cannot be recovered.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('recovery_passphrase_field'),
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Recovery passphrase',
              helperText: 'At least 12 characters',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: importing
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          onPressed: () {
            final value = controller.text;
            if (value.length < 12) return;
            Navigator.pop(dialogContext, value);
          },
          child: Text(importing ? 'Choose archive and replace' : 'Export'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<void> runDisasterRecoveryFlow(
  BuildContext context, {
  required DisasterRecoveryService service,
  required bool importing,
  VoidCallback? onComplete,
}) async {
  final passphrase = await showRecoveryPassphraseDialog(
    context,
    importing: importing,
  );
  if (passphrase == null || !context.mounted) return;
  try {
    if (importing) {
      final selected = await service.pickAndImport(passphrase: passphrase);
      if (!selected || !context.mounted) return;
    } else {
      await service.export(passphrase: passphrase);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          importing
              ? 'Encrypted recovery archive restored.'
              : 'Encrypted recovery archive created.',
        ),
      ),
    );
    onComplete?.call();
  } on DisasterRecoveryAuthenticationException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The passphrase is incorrect or the archive was changed.',
        ),
      ),
    );
  } on Object {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Recovery could not be completed. Local data is unchanged.',
        ),
      ),
    );
  }
}
