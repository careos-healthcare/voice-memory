import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/security/sync_identity_service.dart';
import '../../../shared/ui/animations/canvas_feature_panel.dart';
import '../cloud_relay_sync_engine.dart';

class CloudSyncSettingsSheet extends StatefulWidget {
  const CloudSyncSettingsSheet({
    super.key,
    required this.identity,
    required this.engine,
  });

  final SyncIdentityService identity;
  final CloudRelaySyncEngine engine;

  static Future<void> show(
    BuildContext context, {
    required SyncIdentityService identity,
    required CloudRelaySyncEngine engine,
  }) => showCanvasFeaturePanel<void>(
    context: context,
    routeName: 'cloud-relay-sync',
    builder: (_) => CloudSyncSettingsSheet(identity: identity, engine: engine),
  );

  @override
  State<CloudSyncSettingsSheet> createState() => _CloudSyncSettingsSheetState();
}

class _CloudSyncSettingsSheetState extends State<CloudSyncSettingsSheet> {
  bool? _enabled;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineChanged);
    unawaited(_hydrate());
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _hydrate() async {
    final enabled = await widget.identity.isEnabled;
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    if (!enabled) {
      await _showDisableExplanation();
      return;
    }
    setState(() => _busy = true);
    try {
      final phrase = await widget.identity.enable();
      await widget.engine.syncNow();
      if (!mounted) return;
      setState(() => _enabled = true);
      await _showRecoveryPhrase(phrase);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    if (_busy) return;
    await HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await widget.engine.syncNow();
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(CloudRelayDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Revoke ${device.id}?'),
        content: const Text(
          'This rotates your zero-knowledge sync key. Other devices must be '
          'paired again with the new recovery phrase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-cloud-device-revoke'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rotate & revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final phrase = await widget.engine.revokeDevice(device.id);
      if (mounted) await _showRecoveryPhrase(phrase);
    } on Object catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecoveryPhrase(String phrase) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Save your new recovery phrase'),
      content: SelectableText(
        phrase,
        key: const Key('cloud-sync-recovery-phrase'),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('I saved it'),
        ),
      ],
    ),
  );

  Future<void> _showDisableExplanation() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Encrypted relay remains enabled'),
      content: const Text(
        'To prevent accidental loss, disable or rotate sync from the secure '
        'device-pairing controls after confirming your recovery phrase.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Encrypted relay could not connect. Changes remain safely queued.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final engine = widget.engine;
    return SafeArea(
      top: false,
      child: ListView(
        key: const Key('cloud-sync-settings-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Encrypted Cloud Relay',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close cloud sync settings',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Only AES-256-GCM ciphertext leaves this device. ArchiveMe cannot '
            'read your memories or recover your key.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _RelayStatusCard(engine: engine, busy: _busy, onSync: _syncNow),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('cloud-sync-enabled-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Automatic encrypted relay'),
            subtitle: const Text(
              'Sync in the background when connectivity returns.',
            ),
            value: enabled ?? false,
            onChanged: enabled == null || _busy ? null : _setEnabled,
          ),
          const Divider(height: 28),
          Text(
            'Connected devices',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          if (engine.devices.isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_iphone),
              title: Text('This device'),
              subtitle: Text('No other relay devices have checked in yet.'),
            )
          else
            for (final device in engine.devices)
              ListTile(
                key: Key('cloud-sync-device-${device.id}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  device.isCurrentDevice ? Icons.phone_iphone : Icons.devices,
                ),
                title: Text(device.isCurrentDevice ? 'This device' : device.id),
                subtitle: Text(
                  'Last active ${_timestamp(device.lastActiveAt)}'
                  '${device.keyEpoch > 0 ? ' · Key generation ${device.keyEpoch}' : ''}',
                ),
                trailing: device.isCurrentDevice
                    ? const Chip(label: Text('Current'))
                    : TextButton(
                        key: Key('revoke-cloud-sync-device-${device.id}'),
                        onPressed: _busy ? null : () => _revoke(device),
                        child: const Text('Revoke'),
                      ),
              ),
        ],
      ),
    );
  }
}

class _RelayStatusCard extends StatelessWidget {
  const _RelayStatusCard({
    required this.engine,
    required this.busy,
    required this.onSync,
  });

  final CloudRelaySyncEngine engine;
  final bool busy;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final title = switch (engine.state) {
      CloudRelayConnectionState.disabled => 'Encrypted Relay Off',
      CloudRelayConnectionState.encryptedRelayConnected =>
        'Encrypted Relay Connected',
      CloudRelayConnectionState.syncing => 'Syncing...',
      CloudRelayConnectionState.offlineQueue => 'Offline Queue',
      CloudRelayConnectionState.error => 'Relay Needs Attention',
    };
    final lastSynced = engine.lastSyncedAt;
    final nextRetry = engine.nextRetryAt;
    return Card(
      key: const Key('cloud-sync-status-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (engine.state == CloudRelayConnectionState.syncing)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Icon(
                    engine.state ==
                            CloudRelayConnectionState.encryptedRelayConnected
                        ? Icons.lock_outline
                        : Icons.cloud_off_outlined,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    key: const Key('cloud-sync-status-label'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${engine.pendingCount} encrypted changes waiting'),
            if (lastSynced != null)
              Text('Last synchronized ${_timestamp(lastSynced)}'),
            if (nextRetry != null)
              Text(
                'Retry ${engine.retryAttempt + 1} scheduled '
                '${_timestamp(nextRetry)}',
              ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('cloud-sync-now'),
              onPressed: busy ? null : onSync,
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
          ],
        ),
      ),
    );
  }
}

String _timestamp(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} $hour:$minute';
}
