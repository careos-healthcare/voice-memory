import 'dart:ui';

import 'package:flutter/material.dart';

import '../vault_backup_models.dart';

enum DataPortabilityCredentialMode { recoveryPhrase, customPassword }

enum DataPortabilityCredentialPurpose { backup, restore }

class DataPortabilityCredential {
  const DataPortabilityCredential._(this.mode, this.secret);

  factory DataPortabilityCredential.recoveryPhrase(String phrase) =>
      DataPortabilityCredential._(
        DataPortabilityCredentialMode.recoveryPhrase,
        phrase,
      );

  factory DataPortabilityCredential.customPassword(String password) =>
      DataPortabilityCredential._(
        DataPortabilityCredentialMode.customPassword,
        password,
      );

  final DataPortabilityCredentialMode mode;
  final String secret;
}

typedef DataPortabilityBackupCallback =
    Future<String?> Function(DataPortabilityCredential credential);
typedef DataPortabilityRestoreCallback =
    Future<void> Function(
      String memoryVaultPath,
      DataPortabilityCredential credential,
    );
typedef DataPortabilityMarkdownExportCallback = Future<String?> Function();
typedef DataPortabilityFilePicker = Future<String?> Function();
typedef DataPortabilityFileShare = Future<void> Function(String path);
typedef DataPortabilityBiometricCheck = Future<bool> Function();
typedef DataPortabilitySheetLauncher =
    Future<void> Function(BuildContext context);
typedef DataPortabilitySecretReader =
    Future<String?> Function(
      BuildContext context,
      DataPortabilityCredentialPurpose purpose,
    );

/// A service-free portability surface. All file, credential and vault work is
/// supplied by the caller so secrets never become widget state.
class DataPortabilitySheet extends StatefulWidget {
  const DataPortabilitySheet({
    super.key,
    this.lastBackupAt,
    this.onCreateBackup,
    this.onRestoreBackup,
    this.onExportMarkdown,
    this.pickMemoryVaultFile,
    this.shareFile,
    this.authenticateForExport,
    this.readPassword,
    this.readRecoveryPhrase,
  });

  final DateTime? lastBackupAt;
  final DataPortabilityBackupCallback? onCreateBackup;
  final DataPortabilityRestoreCallback? onRestoreBackup;
  final DataPortabilityMarkdownExportCallback? onExportMarkdown;
  final DataPortabilityFilePicker? pickMemoryVaultFile;
  final DataPortabilityFileShare? shareFile;
  final DataPortabilityBiometricCheck? authenticateForExport;
  final DataPortabilitySecretReader? readPassword;
  final DataPortabilitySecretReader? readRecoveryPhrase;

  static Future<void> show(
    BuildContext context, {
    DateTime? lastBackupAt,
    DataPortabilityBackupCallback? onCreateBackup,
    DataPortabilityRestoreCallback? onRestoreBackup,
    DataPortabilityMarkdownExportCallback? onExportMarkdown,
    DataPortabilityFilePicker? pickMemoryVaultFile,
    DataPortabilityFileShare? shareFile,
    DataPortabilityBiometricCheck? authenticateForExport,
    DataPortabilitySecretReader? readPassword,
    DataPortabilitySecretReader? readRecoveryPhrase,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .42),
    builder: (_) => DataPortabilitySheet(
      lastBackupAt: lastBackupAt,
      onCreateBackup: onCreateBackup,
      onRestoreBackup: onRestoreBackup,
      onExportMarkdown: onExportMarkdown,
      pickMemoryVaultFile: pickMemoryVaultFile,
      shareFile: shareFile,
      authenticateForExport: authenticateForExport,
      readPassword: readPassword,
      readRecoveryPhrase: readRecoveryPhrase,
    ),
  );

  @override
  State<DataPortabilitySheet> createState() => _DataPortabilitySheetState();
}

class _DataPortabilitySheetState extends State<DataPortabilitySheet> {
  bool _busy = false;
  String? _progress;
  String? _error;
  String? _success;
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _lastBackupAt = widget.lastBackupAt;
  }

  Future<void> _run(
    String progress,
    Future<String> Function() operation,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = progress;
      _error = null;
      _success = null;
    });
    try {
      final success = await operation();
      if (mounted) setState(() => _success = success);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is VaultBackupAuthenticationException) {
      return 'The password or recovery phrase is wrong, or the backup was tampered with.';
    }
    if (error is VaultBackupException) return error.message;
    if (error is StateError) return error.message;
    return 'Something went wrong. Your vault was not changed.';
  }

  Future<DataPortabilityCredential?> _requestCredential(
    DataPortabilityCredentialPurpose purpose,
  ) async {
    final mode = await showDialog<DataPortabilityCredentialMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          purpose == DataPortabilityCredentialPurpose.backup
              ? 'Protect your backup'
              : 'Unlock this backup',
        ),
        content: const Text(
          'Use your 12-word recovery phrase or a custom password.',
        ),
        actions: [
          TextButton(
            key: const Key('portability_credential_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('portability_phrase_mode'),
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(DataPortabilityCredentialMode.recoveryPhrase),
            child: const Text('Recovery phrase'),
          ),
          FilledButton(
            key: const Key('portability_password_mode'),
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(DataPortabilityCredentialMode.customPassword),
            child: const Text('Custom password'),
          ),
        ],
      ),
    );
    if (!mounted || mode == null) return null;

    if (mode == DataPortabilityCredentialMode.recoveryPhrase) {
      final phrase =
          await (widget.readRecoveryPhrase?.call(context, purpose) ??
              _showRecoveryPhraseDialog(purpose));
      if (phrase == null) return null;
      return DataPortabilityCredential.recoveryPhrase(phrase);
    }

    final password =
        await (widget.readPassword?.call(context, purpose) ??
            _showPasswordDialog(purpose));
    if (password == null) return null;
    return DataPortabilityCredential.customPassword(password);
  }

  Future<String?> _showPasswordDialog(
    DataPortabilityCredentialPurpose purpose,
  ) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? validation;
    try {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Custom password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Use at least 12 characters. This password cannot be recovered.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('portability_password'),
                    controller: password,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('portability_password_confirmation'),
                    controller: confirmation,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      errorText: validation,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('portability_password_continue'),
                onPressed: () {
                  final value = password.text;
                  final error = value.length < 12
                      ? 'Password must be at least 12 characters.'
                      : value != confirmation.text
                      ? 'Passwords do not match.'
                      : null;
                  if (error != null) {
                    setDialogState(() => validation = error);
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: Text(
                  purpose == DataPortabilityCredentialPurpose.restore
                      ? 'Unlock'
                      : 'Continue',
                ),
              ),
            ],
          ),
        ),
      );
      password.clear();
      confirmation.clear();
      // showDialog completes when pop begins. Keep the now-empty controllers
      // alive until the reverse transition has detached its text fields.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return result;
    } finally {
      password.clear();
      confirmation.clear();
      password.dispose();
      confirmation.dispose();
    }
  }

  Future<String?> _showRecoveryPhraseDialog(
    DataPortabilityCredentialPurpose purpose,
  ) async {
    final phrase = TextEditingController();
    String? validation;
    try {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Recovery phrase'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter all 12 words, separated by spaces.'),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('portability_recovery_phrase'),
                  controller: phrase,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: '12-word recovery phrase',
                    errorText: validation,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('portability_phrase_continue'),
                onPressed: () {
                  final value = phrase.text.trim().replaceAll(
                    RegExp(r'\s+'),
                    ' ',
                  );
                  if (value.split(' ').length != 12) {
                    setDialogState(
                      () => validation = 'Enter exactly 12 words.',
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: Text(
                  purpose == DataPortabilityCredentialPurpose.restore
                      ? 'Unlock'
                      : 'Continue',
                ),
              ),
            ],
          ),
        ),
      );
      phrase.clear();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return result;
    } finally {
      phrase.clear();
      phrase.dispose();
    }
  }

  Future<void> _createBackup() async {
    final credential = await _requestCredential(
      DataPortabilityCredentialPurpose.backup,
    );
    if (!mounted || credential == null) return;
    await _run('Encrypting backup…', () async {
      final create = widget.onCreateBackup;
      if (create == null) {
        throw StateError('Backup is not available on this device yet.');
      }
      final path = await create(credential);
      if (path != null && widget.shareFile != null) {
        if (mounted) setState(() => _progress = 'Preparing secure share…');
        await widget.shareFile!(path);
        _lastBackupAt = DateTime.now();
      }
      return 'Encrypted backup created.';
    });
  }

  Future<void> _restoreBackup() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Replace this vault?'),
            content: const Text(
              'Restoring clears the current local vault before importing the '
              '.memoryvault file. This cannot be undone.',
            ),
            actions: [
              TextButton(
                key: const Key('portability_restore_cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep current vault'),
              ),
              FilledButton(
                key: const Key('portability_restore_confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Clear and continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    final picker = widget.pickMemoryVaultFile;
    if (picker == null) {
      setState(() => _error = 'File picker is not available on this device.');
      return;
    }
    final path = await picker();
    if (!mounted || path == null) return;
    if (!path.toLowerCase().endsWith('.memoryvault')) {
      setState(() => _error = 'Choose a .memoryvault backup file.');
      return;
    }

    final credential = await _requestCredential(
      DataPortabilityCredentialPurpose.restore,
    );
    if (!mounted || credential == null) return;
    await _run('Restoring encrypted vault…', () async {
      final restore = widget.onRestoreBackup;
      if (restore == null) {
        throw StateError('Restore is not available on this device yet.');
      }
      await restore(path, credential);
      return 'Vault restored successfully.';
    });
  }

  Future<void> _exportMarkdown() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Export readable Markdown?'),
            content: const Text(
              'This export is not encrypted and may contain private memories. '
              'Anyone with the file can read it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('portability_markdown_confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Authenticate'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    await _run('Confirming your identity…', () async {
      final authenticate = widget.authenticateForExport;
      if (authenticate != null && !await authenticate()) {
        throw StateError('Biometric authentication was not completed.');
      }
      final export = widget.onExportMarkdown;
      if (export == null) {
        throw StateError(
          'Markdown export is not available on this device yet.',
        );
      }
      if (mounted) setState(() => _progress = 'Creating Markdown export…');
      final path = await export();
      if (path != null && widget.shareFile != null) {
        if (mounted) setState(() => _progress = 'Preparing private share…');
        await widget.shareFile!(path);
      }
      return 'Markdown export created.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Material(
              key: const Key('data_portability_sheet'),
              color: scheme.surface.withValues(alpha: .9),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(context),
                          if (_busy) ...[
                            const SizedBox(height: 8),
                            Semantics(
                              liveRegion: true,
                              label: _progress,
                              child: LinearProgressIndicator(
                                key: const Key('portability_busy_indicator'),
                                semanticsLabel: _progress,
                              ),
                            ),
                          ],
                          if (_error != null)
                            _StatusMessage(
                              key: const Key('portability_error'),
                              icon: Icons.error_outline,
                              message: _error!,
                              color: scheme.error,
                            ),
                          if (_success != null)
                            _StatusMessage(
                              key: const Key('portability_success'),
                              icon: Icons.check_circle_outline,
                              message: _success!,
                              color: Colors.green.shade700,
                            ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 36,
                              ),
                              children: [
                                _section(
                                  context,
                                  icon: Icons.enhanced_encryption_outlined,
                                  title: 'Encrypted Backup',
                                  body:
                                      'Create a portable .memoryvault file protected '
                                      'by your chosen credential.',
                                  status: _lastBackupLabel(),
                                  buttonKey: const Key(
                                    'portability_create_backup',
                                  ),
                                  buttonLabel: 'Create Backup',
                                  onPressed: _busy ? null : _createBackup,
                                  primary: true,
                                ),
                                _section(
                                  context,
                                  icon: Icons.settings_backup_restore,
                                  title: 'Restore Vault',
                                  body:
                                      'Choose a .memoryvault file. Your current local '
                                      'vault will be cleared only after you confirm.',
                                  warning:
                                      'Destructive: replaces the current vault.',
                                  buttonKey: const Key(
                                    'portability_restore_backup',
                                  ),
                                  buttonLabel: 'Choose .memoryvault file',
                                  onPressed: _busy ? null : _restoreBackup,
                                ),
                                _section(
                                  context,
                                  icon: Icons.description_outlined,
                                  title: 'Human-readable export',
                                  body:
                                      'Export your memories as Markdown. The result is '
                                      'readable, unencrypted, and requires biometrics.',
                                  warning:
                                      'Privacy warning: store and share this file carefully.',
                                  buttonKey: const Key(
                                    'portability_export_markdown',
                                  ),
                                  buttonLabel: 'Authenticate & export Markdown',
                                  onPressed: _busy ? null : _exportMarkdown,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          'Export, backup & portability',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      IconButton(
        tooltip: 'Close data portability',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
    ],
  );

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required Key buttonKey,
    required String buttonLabel,
    required VoidCallback? onPressed,
    String? status,
    String? warning,
    bool primary = false,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body),
          if (status != null) ...[
            const SizedBox(height: 8),
            Text(status, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (warning != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Warning: $warning',
              child: Text(
                warning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Semantics(
            button: true,
            enabled: onPressed != null,
            label: buttonLabel,
            child: primary
                ? FilledButton(
                    key: buttonKey,
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(buttonLabel, textAlign: TextAlign.center),
                  )
                : OutlinedButton(
                    key: buttonKey,
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(buttonLabel, textAlign: TextAlign.center),
                  ),
          ),
        ],
      ),
    ),
  );

  String _lastBackupLabel() {
    final value = _lastBackupAt;
    if (value == null) return 'Last backup: Never';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return 'Last backup: ${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    ),
  );
}
