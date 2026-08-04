import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/security/sync_identity_service.dart';
import 'device_pairing_scanner.dart';
import 'encrypted_sync_engine.dart';

class SyncSettingsSheet extends StatefulWidget {
  const SyncSettingsSheet({
    super.key,
    required this.identity,
    required this.engine,
  });

  final SyncIdentityService identity;
  final EncryptedSyncEngine engine;

  static Future<void> show(
    BuildContext context, {
    required SyncIdentityService identity,
    required EncryptedSyncEngine engine,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .4),
    builder: (_) => FractionallySizedBox(
      heightFactor: .92,
      child: SyncSettingsSheet(identity: identity, engine: engine),
    ),
  );

  @override
  State<SyncSettingsSheet> createState() => _SyncSettingsSheetState();
}

class _SyncSettingsSheetState extends State<SyncSettingsSheet> {
  String? _phrase;
  String? _pairingPayload;
  String? _pairingCode;
  var _revealPhrase = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final phrase = await widget.identity.recoveryPhrase();
    if (mounted) setState(() => _phrase = phrase);
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      final phrase = await widget.identity.enable();
      if (!mounted) return;
      setState(() {
        _phrase = phrase;
        _revealPhrase = true;
      });
      await widget.engine.syncNow();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createPairingQr() async {
    final code = Random.secure().nextInt(1000000).toString().padLeft(6, '0');
    final payload = await widget.identity.createPairingPayload(code);
    if (!mounted) return;
    setState(() {
      _pairingCode = code;
      _pairingPayload = payload;
    });
  }

  Future<void> _scan() async {
    String? payload;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            DevicePairingScanner(onPayload: (value) => payload = value),
      ),
    );
    if (!mounted || payload == null) return;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter the 6-digit pairing code'),
        content: TextField(
          key: const Key('sync-pairing-code-entry'),
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Pair'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null) return;
    await widget.identity.acceptPairingPayload(payload!, pairingCode: code);
    await _refresh();
    await widget.engine.syncNow();
  }

  Future<void> _revoke(SyncDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Revoke ${device.id}?'),
        content: const Text(
          'ArchiveMe will rotate the encryption key and re-encrypt the graph. '
          'Other trusted devices must be paired again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rotate & revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final phrase = await widget.engine.revokeDevice(device.id);
      await widget.engine.syncNow();
      if (!mounted) return;
      setState(() {
        _phrase = phrase;
        _revealPhrase = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _phrase;
    return ClipRRect(
      key: const Key('sync-settings-sheet'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
          child: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                Row(
                  children: [
                    const Icon(Icons.enhanced_encryption_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Encrypted sync & devices',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close sync settings',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  state: widget.engine.state,
                  pendingCount: widget.engine.outbox.pendingCount,
                  onSync: _busy ? null : widget.engine.syncNow,
                ),
                const SizedBox(height: 20),
                if (phrase == null)
                  FilledButton.icon(
                    key: const Key('enable-encrypted-sync'),
                    onPressed: _busy ? null : _enable,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Enable end-to-end encrypted sync'),
                  )
                else ...[
                  Text(
                    'Recovery phrase',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Write these 12 words down. ArchiveMe cannot recover them.',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('sync-recovery-phrase'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      _revealPhrase
                          ? phrase
                          : List.filled(12, '••••').join('  '),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _revealPhrase = !_revealPhrase),
                    icon: Icon(
                      _revealPhrase ? Icons.visibility_off : Icons.visibility,
                    ),
                    label: Text(
                      _revealPhrase ? 'Hide phrase' : 'Reveal phrase',
                    ),
                  ),
                  const Divider(height: 28),
                  Text(
                    'Pair another device',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'The QR payload is encrypted. Enter the separate six-digit '
                    'code on the new device.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        key: const Key('create-pairing-qr'),
                        onPressed: _createPairingQr,
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('Show pairing QR'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('scan-pairing-qr'),
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR'),
                      ),
                    ],
                  ),
                  if (_pairingPayload case final payload?) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: QrImageView(
                            key: const Key('sync-pairing-qr'),
                            data: payload,
                            size: 196,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: SelectableText(
                        'Pairing code: $_pairingCode',
                        key: const Key('sync-pairing-code'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                  const Divider(height: 28),
                  Text(
                    'Connected devices',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (widget.engine.devices.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.phone_iphone),
                      title: Text('This device'),
                      subtitle: Text('No other devices have synced yet.'),
                    ),
                  for (final device in widget.engine.devices)
                    ListTile(
                      key: Key('sync-device-${device.id}'),
                      leading: const Icon(Icons.devices),
                      title: Text(
                        device.isCurrentDevice ? 'This device' : device.id,
                      ),
                      subtitle: Text(
                        'Last seen ${device.lastSeenAt.toLocal()} · '
                        'Key generation ${device.keyEpoch}',
                      ),
                      trailing: device.isCurrentDevice
                          ? const Chip(label: Text('Current'))
                          : TextButton(
                              key: Key('revoke-sync-device-${device.id}'),
                              onPressed: _busy ? null : () => _revoke(device),
                              child: const Text('Revoke'),
                            ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.pendingCount,
    required this.onSync,
  });

  final EncryptedSyncState state;
  final int pendingCount;
  final Future<void> Function()? onSync;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: state == EncryptedSyncState.syncing
          ? const CircularProgressIndicator()
          : Icon(
              state == EncryptedSyncState.upToDate
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_sync_outlined,
            ),
      title: Text(switch (state) {
        EncryptedSyncState.disabled => 'Encrypted sync is off',
        EncryptedSyncState.offline => 'Offline — changes are safely queued',
        EncryptedSyncState.syncing => 'Syncing encrypted changes…',
        EncryptedSyncState.upToDate => 'Encrypted archive is up to date',
        EncryptedSyncState.error => 'Sync needs attention',
      }),
      subtitle: Text('$pendingCount local changes waiting'),
      trailing: IconButton(
        tooltip: 'Sync now',
        onPressed: onSync == null ? null : () => onSync!(),
        icon: const Icon(Icons.sync),
      ),
    ),
  );
}
