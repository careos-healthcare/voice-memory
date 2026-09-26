import 'package:flutter/material.dart';

/// Shown before any import so the person knows where the files will go.
class ImportConsentView extends StatelessWidget {
  const ImportConsentView({required this.onContinue, super.key});

  final VoidCallback onContinue;

  static const message =
      'Imports are saved securely to your device. If you enable Cloud Backup, '
      'they will be encrypted and synced to our servers.';

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('import_consent_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          key: const Key('import_consent_message'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('import_consent_continue'),
          onPressed: onContinue,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
