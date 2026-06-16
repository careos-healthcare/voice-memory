import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error_message.dart';
import '../services/app_services.dart';
import '../widgets/pushed_screen_shell.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _busy = false;

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await AppServices.instance.api.deleteAccount();
      await AppServices.instance.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deletion requested.')),
        );
        context.go('/record');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingErrorMessage(
                e,
                fallback: 'Account deletion failed. Try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: 'Delete account',
      doneLabel: 'Cancel',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This permanently deletes your server account and synced data. '
              'Local reflections on this device are not removed unless you clear app data.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _busy ? null : _delete,
              child: _busy
                  ? const CircularProgressIndicator()
                  : const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
  }
}
