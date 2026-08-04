import 'dart:async';

import 'package:flutter/material.dart';

import '../../security/sensitive_screen_guard.dart';
import '../../services/app_services.dart';
import '../journal/sync/saved_moment_sync_key_store.dart';
import 'sync_recovery_code_actions.dart';
import 'sync_recovery_service.dart';

class SyncRecoveryScreen extends StatefulWidget {
  const SyncRecoveryScreen({super.key, this.service, this.codeActions});

  final SyncRecoveryService? service;
  final SyncRecoveryCodeActions? codeActions;

  @override
  State<SyncRecoveryScreen> createState() => _SyncRecoveryScreenState();
}

class _SyncRecoveryScreenState extends State<SyncRecoveryScreen> {
  late final SyncRecoveryService _service =
      widget.service ??
      SyncRecoveryService(
        api: AppServices.instance.journalSyncApi,
        keyStore: SavedMomentSyncKeyStore(AppServices.instance.secureStorage),
        identityProvider: () =>
            AppServices.instance.composition.account.activeArchiveIdentity,
        adoptRecoveredArchive:
            AppServices.instance.composition.account.adoptRecoveredArchive,
      );
  late final SyncRecoveryCodeActions _codeActions =
      widget.codeActions ?? SyncRecoveryCodeActions();
  final _codeController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  String? _oneTimeCode;
  DateTime? _oneTimeCodeCreatedAt;
  int? _oneTimeCodeRevision;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _service.status();
      if (!mounted) return;
      setState(() {
        _enabled = status.enabled;
        _message = null;
      });
    } on Object {
      if (mounted) {
        setState(
          () => _message =
              'Recovery status is unavailable. Your local archive is unchanged.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setup() async {
    setState(() {
      _busy = true;
      _message = null;
      _confirmationController.clear();
    });
    try {
      final setup = await _service.enableOrReplace();
      if (!mounted) return;
      setState(() {
        _enabled = true;
        _oneTimeCode = setup.secret;
        _oneTimeCodeCreatedAt = setup.envelope.updatedAt;
        _oneTimeCodeRevision = setup.envelope.envelopeRevision;
      });
    } on Object {
      if (mounted) {
        setState(
          () => _message =
              'Recovery could not be set up. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyOneTimeCode() async {
    final code = _oneTimeCode;
    if (code == null) return;
    try {
      await _codeActions.copy(code);
      if (mounted) {
        setState(() => _message = 'Recovery code copied.');
      }
    } on Object {
      if (mounted) {
        setState(() => _message = 'Recovery code could not be copied.');
      }
    }
  }

  Future<void> _printOneTimeCode() async {
    final code = _oneTimeCode;
    final createdAt = _oneTimeCodeCreatedAt;
    final revision = _oneTimeCodeRevision;
    if (code == null || createdAt == null || revision == null) return;
    setState(() => _busy = true);
    try {
      await _codeActions.printInstructions(
        recoveryCode: code,
        createdAt: createdAt,
        envelopeRevision: revision,
      );
      if (mounted) {
        setState(
          () => _message = 'Print handoff finished. Temporary file deleted.',
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _message =
              'Printing was cancelled or failed. Temporary file deleted.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmSavedCode() {
    final code = _oneTimeCode;
    if (code == null) return;
    if (_confirmationController.text.trim() != code) {
      setState(
        () => _message =
            'Confirmation does not match. Re-enter the complete recovery code.',
      );
      return;
    }
    _confirmationController.clear();
    setState(() {
      _oneTimeCode = null;
      _oneTimeCodeCreatedAt = null;
      _oneTimeCodeRevision = null;
      _message =
          'Recovery is enabled. The one-time code cannot be displayed again.';
    });
  }

  Future<void> _verify({required bool recover}) async {
    final code = _codeController.text;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (recover) {
        await _service.recover(code);
        if (mounted) {
          setState(() => _message = 'Sync key recovered on this device.');
        }
      } else {
        final verified = await _service.verify(code);
        if (mounted) {
          setState(
            () => _message = verified
                ? 'Recovery code verified.'
                : 'That code does not match this archive.',
          );
        }
      }
    } on Object {
      if (mounted) {
        setState(
          () => _message =
              'Recovery failed closed. Check the full code and signed-in account.',
        );
      }
    } finally {
      _codeController.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    try {
      await _service.disable();
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _oneTimeCode = null;
        _oneTimeCodeCreatedAt = null;
        _oneTimeCodeRevision = null;
        _message =
            'Cloud recovery disabled. Existing synced data stays encrypted.';
      });
    } on Object {
      if (mounted) {
        setState(() => _message = 'Recovery could not be disabled.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDisable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable sync recovery?'),
        content: const Text(
          'This deletes the encrypted recovery wrapping from the server. '
          'Your synced data stays encrypted, but the saved code will stop '
          'working. Export your archive first. If you then lose every device '
          'holding the sync key, recovery is permanently impossible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable recovery'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _disable();
  }

  @override
  Widget build(BuildContext context) => SensitiveScreenScope(
    child: Scaffold(
      appBar: AppBar(title: const Text('Encrypted sync recovery')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Optional recovery wraps your existing random sync key with a '
                  'code created on this device. The server stores only the '
                  'encrypted wrapping; it cannot read your archive or code.',
                ),
                const SizedBox(height: 8),
                Text(
                  _enabled
                      ? 'Status: Recovery enabled'
                      : 'Status: Recovery not set up',
                  key: const Key('sync_recovery_status'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The recovery code is shown once during setup. It is never '
                  'included in an ordinary archive export.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recovery requires both your signed-in account and this code. '
                  'Store the code offline and separately. Anyone with both may '
                  'recover the archive. If you lose the code and every device '
                  'holding the sync key, the encrypted cloud copy is permanently '
                  'unrecoverable.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (_oneTimeCode != null) ...[
                  const SizedBox(height: 24),
                  const Text('Save this recovery code now. It is shown once.'),
                  const SizedBox(height: 8),
                  SelectableText(
                    _oneTimeCode!,
                    key: const Key('sync_recovery_one_time_code'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('sync_recovery_copy'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _copyOneTimeCode,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy recovery code'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('sync_recovery_print'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _printOneTimeCode,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print recovery instructions'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('sync_recovery_confirmation_input'),
                    controller: _confirmationController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Re-enter the complete recovery code',
                      helperText:
                          'This confirms you saved the actual code, not just this screen.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('sync_recovery_confirm_saved'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _busy ? null : _confirmSavedCode,
                    child: const Text('Confirm and hide code'),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('sync_recovery_setup'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: _busy ? null : _setup,
                    child: Text(
                      _enabled ? 'Replace recovery code' : 'Set up recovery',
                    ),
                  ),
                  if (_enabled)
                    TextButton(
                      key: const Key('sync_recovery_disable'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _busy ? null : _confirmDisable,
                      child: const Text('Disable recovery'),
                    ),
                  const Divider(height: 32),
                  TextField(
                    key: const Key('sync_recovery_code_input'),
                    controller: _codeController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Recovery code',
                      helperText:
                          'Paste the complete code. It is never logged.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('sync_recovery_verify'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : () => _verify(recover: false),
                        child: const Text('Verify code'),
                      ),
                      FilledButton.tonal(
                        key: const Key('sync_recovery_restore'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : () => _verify(recover: true),
                        child: const Text('Recover on this device'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Ordinary archive exports omit the recovery code. Keep your '
                  'own separate copy before replacing devices. Export your '
                  'archive before disabling recovery or deleting your account.',
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, key: const Key('sync_recovery_message')),
                ],
              ],
            ),
    ),
  );
}
