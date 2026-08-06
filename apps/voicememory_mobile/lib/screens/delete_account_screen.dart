import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_error_message.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/security/wipe_local_archive_dialog.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _busy = false;

  static const String _confirmTitle = 'Delete account permanently?';
  static const String _confirmBody =
      'This cannot be undone. Your server account and synced data will be '
      'permanently deleted.';
  static const String _confirmAccept = 'Delete permanently';
  static const String _confirmCancel = 'Cancel';

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('delete_account_confirm_dialog'),
        title: const Text(_confirmTitle),
        content: const Text(_confirmBody),
        actions: [
          TextButton(
            key: const Key('delete_account_confirm_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(_confirmCancel),
          ),
          TextButton(
            key: const Key('delete_account_confirm_accept'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(_confirmAccept),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _onDeletePressed() async {
    if (!await _confirmDelete()) return;
    if (!mounted) return;
    await _delete();
  }

  /// Second, explicit choice shown only after server deletion has already
  /// succeeded: this device may still hold a local copy of this account's
  /// reflections, separate from what was just deleted server-side. Reuses
  /// the existing double-confirmation wipe dialog ([showWipeLocalArchiveDialog]),
  /// which only ever acts on the *currently active* namespace's journal/prefs.
  Future<void> _offerLocalDataWipe() async {
    final wantsLocalWipe = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('delete_account_local_wipe_offer_dialog'),
        title: const Text('Server data deleted'),
        content: const Text(
          'Your ArchiveMe account and synced data have been deleted from '
          "our servers. This device may still have a local copy of this "
          "account's reflections — that is separate and not affected by "
          'the step you just completed. Delete the local copy too?',
        ),
        actions: [
          TextButton(
            key: const Key('delete_account_local_wipe_skip'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep local copy'),
          ),
          TextButton(
            key: const Key('delete_account_local_wipe_accept'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete local copy too'),
          ),
        ],
      ),
    );
    if (wantsLocalWipe != true || !mounted) return;
    await showWipeLocalArchiveDialog(context);
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await AppServices.instance.api.deleteAccount();
      // Server deletion and local-device deletion are two separate steps —
      // offer the second one explicitly, and do it *before* signOut()
      // below switches the active namespace to guest, so the wipe dialog
      // (which acts on whatever namespace is currently active) still
      // targets this account's own local copy, never another account's.
      if (mounted) {
        await _offerLocalDataWipe();
      }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Deleting your account is two separate steps. First, your '
              'server account and synced data are permanently deleted. '
              "Then you'll be asked whether to also delete this device's "
              'local copy of your reflections — that local copy is not '
              'touched by the server step alone, and other accounts ever '
              'used on this device are never affected either way.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('delete_account_button'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _busy ? null : _onDeletePressed,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : const Text('Delete account'),
            ),
          ],
        ),
      ),
    );
  }
}
