import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/core/storage/secure_storage_provider.dart';
import 'package:archiveme_mobile/features/settings/views/e2ee_setup_view.dart';
import 'package:archiveme_mobile/features/sync/services/account_sync_key.dart';
import 'package:archiveme_mobile/features/sync/services/device_pairing_service.dart';
import 'package:archiveme_mobile/features/sync/views/recovery_key_backup_view.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:flutter/material.dart';

/// Settings switch that generates a passphrase and asks the user to keep it.
class E2eeSyncSettings extends StatefulWidget {
  const E2eeSyncSettings({
    super.key,
    required this.readEnabled,
    required this.writeEnabled,
    required this.storePassphrase,
    this.generatePassphrase = AccountSyncKey.recoveryPhrase,
    this.saveMasterKey,
  });

  static const preferenceKey = 'e2ee_sync_enabled';
  static const passphraseKey = 'e2ee_sync_passphrase';

  final Future<bool> Function() readEnabled;
  final Future<void> Function(bool enabled) writeEnabled;
  final Future<void> Function(String passphrase) storePassphrase;
  final String Function() generatePassphrase;
  final Future<void> Function(
    List<int> masterKey,
    List<int> salt,
    MasterKeyKeychainScope scope,
  )?
  saveMasterKey;

  /// Writes the passphrase into the same secure store as the wrapped account key.
  static Future<void> storeInVault(String passphrase) {
    return accountKeySecureStorage.write(key: passphraseKey, value: passphrase);
  }

  static Future<String?> storedPassphrase() {
    return accountKeySecureStorage.read(key: passphraseKey);
  }

  @override
  State<E2eeSyncSettings> createState() => _E2eeSyncSettingsState();
}

class _E2eeSyncSettingsState extends State<E2eeSyncSettings> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.readEnabled().then((value) {
        if (mounted) setState(() => _enabled = value);
      }),
    );
  }

  Future<void> _toggle(bool next) async {
    if (!next) {
      await widget.writeEnabled(false);
      if (mounted) setState(() => _enabled = false);
      return;
    }
    final generated = widget.generatePassphrase();
    if (!mounted) return;
    final stored = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => E2eeSetupView(
          generatePassphrase: () => generated,
        ),
      ),
    );
    if (stored == null || stored.trim().isEmpty || !mounted) return;
    if (stored == generated && RecoveryKey.looksLike(stored)) {
      final scope = await Navigator.of(context).push<MasterKeyKeychainScope>(
        MaterialPageRoute<MasterKeyKeychainScope>(
          builder: (_) => RecoveryKeyBackupView(phrase: stored),
        ),
      );
      if (scope == null || !mounted) return;
      final accountKey = AccountSyncKey.generate();
      final bundle = await AccountSyncKey.wrap(
        accountKey: accountKey,
        passphrase: stored,
        recoveryPhrase: stored,
      );
      await AccountSyncKey.storeBundle(bundle);
      try {
        await AccountSyncKeyImport.publish(bundle);
      } on Object {
        // The next successful sync can publish the same wrapped key.
      }
      final save = widget.saveMasterKey;
      if (save != null) {
        await save(accountKey, base64Decode(bundle.wrappedByPassphrase.salt), scope);
      }
    } else {
      try {
        await AccountSyncKeyImport.importExisting(passphrase: stored);
      } on Object {
        // The passphrase is still saved. Sync retries the parameter fetch.
      }
    }
    await widget.storePassphrase(stored);
    await widget.writeEnabled(true);
    if (mounted) setState(() => _enabled = true);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const Key('settings_e2ee_sync'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Enable E2EE Sync'),
      subtitle: const Text(
        'Encrypt journal entries before they leave this phone.',
      ),
      value: _enabled,
      onChanged: _toggle,
    );
  }
}

/// Face ID (or the device biometric) before the recovery phrase is shown.
abstract final class RecoveryKeyReveal {
  RecoveryKeyReveal._();

  static Future<bool> Function(String reason)? debugConfirm;

  static Future<bool> confirm() {
    final override = debugConfirm;
    const reason = 'Show your Thoughtprint recovery key';
    if (override != null) return override(reason);
    return LocalAuthBiometricAuthenticator().authenticate(reason);
  }
}

class E2eeSyncDevice {
  const E2eeSyncDevice({
    required this.id,
    required this.name,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final String lastSeen;
}

/// Status, devices, and recovery actions for record sync.
class E2eeSyncStatusPanel extends StatelessWidget {
  const E2eeSyncStatusPanel({
    required this.status,
    required this.devices,
    required this.onRemoveDevice,
    required this.onChangePassphrase,
    required this.onShowRecoveryKey,
    required this.onTurnOff,
    this.downloadOnWifi = false,
    this.onDownloadOnWifi,
    super.key,
  });

  final String status;
  final List<E2eeSyncDevice> devices;
  final ValueChanged<String> onRemoveDevice;
  final VoidCallback onChangePassphrase;
  final VoidCallback onShowRecoveryKey;
  final VoidCallback onTurnOff;
  final bool downloadOnWifi;
  final ValueChanged<bool>? onDownloadOnWifi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(status, key: const Key('e2ee_sync_status')),
        SwitchListTile(
          key: const Key('e2ee_download_on_wifi'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Download all media on Wi-Fi'),
          value: downloadOnWifi,
          onChanged: onDownloadOnWifi,
        ),
        for (final device in devices)
          ListTile(
            key: Key('e2ee_device_${device.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(device.name),
            subtitle: Text(device.lastSeen),
            trailing: TextButton(
              key: Key('e2ee_remove_device_${device.id}'),
              onPressed: () => onRemoveDevice(device.id),
              child: const Text('Remove device'),
            ),
          ),
        TextButton(
          key: const Key('e2ee_change_passphrase'),
          onPressed: onChangePassphrase,
          child: const Text('Change passphrase'),
        ),
        TextButton(
          key: const Key('e2ee_show_recovery_key'),
          onPressed: onShowRecoveryKey,
          child: const Text('Show recovery key'),
        ),
        const Text('Showing the recovery key asks for Face ID first.'),
        TextButton(
          key: const Key('e2ee_turn_off_sync'),
          onPressed: onTurnOff,
          child: const Text('Turn off sync and delete server copy'),
        ),
      ],
    );
  }
}
