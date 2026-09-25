import 'dart:async';

import 'package:archiveme_mobile/core/crypto/passphrase_vault.dart';
import 'package:archiveme_mobile/sync/e2ee_journal_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Settings switch that generates a passphrase and asks the user to keep it.
class E2eeSyncSettings extends StatefulWidget {
  const E2eeSyncSettings({
    super.key,
    required this.readEnabled,
    required this.writeEnabled,
    required this.storePassphrase,
    this.generatePassphrase = E2eeJournalSync.generatePassphrase,
  });

  static const preferenceKey = 'e2ee_sync_enabled';
  static const passphraseKey = 'e2ee_sync_passphrase';

  final Future<bool> Function() readEnabled;
  final Future<void> Function(bool enabled) writeEnabled;
  final Future<void> Function(String passphrase) storePassphrase;
  final String Function() generatePassphrase;

  /// Writes the passphrase into the same secure store the vault uses.
  static Future<void> storeInVault(String passphrase) {
    return SaltStore.secureStorage().write(passphraseKey, passphrase);
  }

  @override
  State<E2eeSyncSettings> createState() => _E2eeSyncSettingsState();
}

class _E2eeSyncSettingsState extends State<E2eeSyncSettings> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.readEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    }));
  }

  Future<void> _toggle(bool next) async {
    if (!next) {
      await widget.writeEnabled(false);
      if (mounted) setState(() => _enabled = false);
      return;
    }
    final passphrase = widget.generatePassphrase();
    if (!mounted) return;
    final stored = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Store your sync passphrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you lose this passphrase, your synced data cannot be recovered. We cannot reset it for you.',
            ),
            const SizedBox(height: 12),
            SelectableText(passphrase),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: passphrase)));
              Navigator.pop(context, true);
            },
            child: const Text("I've stored it"),
          ),
        ],
      ),
    );
    if (stored != true) return;
    await widget.storePassphrase(passphrase);
    await widget.writeEnabled(true);
    if (mounted) setState(() => _enabled = true);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const Key('settings_e2ee_sync'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Enable E2EE Sync'),
      subtitle: const Text('Encrypt journal entries before they leave this phone.'),
      value: _enabled,
      onChanged: _toggle,
    );
  }
}
