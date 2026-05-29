import 'package:flutter/material.dart';

import '../widgets/placeholder_panel.dart';
import '../widgets/scaffold_shell.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldShell(
      title: 'Delete account',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PlaceholderPanel(
            title: 'Permanent deletion (not implemented)',
            body:
                'Web flow: POST /api/account/delete. Native must call same API with session.',
            status: 'Required for App Store / Play — not wired',
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Not implemented — use web account deletion.'),
                ),
              );
            },
            child: const Text('Delete account (disabled)'),
          ),
        ],
      ),
    );
  }
}
