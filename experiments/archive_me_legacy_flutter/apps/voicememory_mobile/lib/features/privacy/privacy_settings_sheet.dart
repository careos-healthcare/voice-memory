import 'package:flutter/material.dart';

import '../../services/security/biometric_vault_service.dart';

class PrivacySettingsSheet extends StatefulWidget {
  const PrivacySettingsSheet({super.key, this.service});

  final BiometricVaultService? service;

  @override
  State<PrivacySettingsSheet> createState() => _PrivacySettingsSheetState();
}

class _PrivacySettingsSheetState extends State<PrivacySettingsSheet> {
  BiometricVaultService get _service =>
      widget.service ?? BiometricVaultService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        await _service.enable();
      } else {
        await _service.disable();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        key: const Key('privacy-settings-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Biometric Vault',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Protect the local encryption key with Face ID, Touch ID, or '
            'your device credential.',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('biometric-vault-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Require device authentication'),
            subtitle: const Text(
              'Key material is cleared from memory whenever the vault locks.',
            ),
            value: _service.isEnabled,
            onChanged: _busy ? null : _toggle,
          ),
          if (_service.isEnabled) ...[
            const Divider(),
            Text('Auto-lock', style: Theme.of(context).textTheme.titleMedium),
            for (final option in VaultAutoLock.values)
              ListTile(
                key: Key('vault-auto-lock-${option.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                trailing: _service.autoLock == option
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.circle_outlined),
                onTap: () => _service.setAutoLock(option),
              ),
          ],
        ],
      ),
    ),
  );
}
