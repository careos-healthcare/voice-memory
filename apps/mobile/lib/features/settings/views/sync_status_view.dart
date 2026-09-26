import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/core/crypto/account_sync_key.dart';
import 'package:archiveme_mobile/features/settings/e2ee_sync_settings.dart';
import 'package:archiveme_mobile/features/sync/services/account_sync_key.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One phone that can sync this journal.
class ConnectedDevice {
  const ConnectedDevice({
    required this.id,
    required this.name,
    required this.lastActive,
    required this.syncToken,
    this.platform = '',
  });

  factory ConnectedDevice.fromJson(Map<String, Object?> json) {
    final token = json['syncToken'];
    return ConnectedDevice(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Phone'}',
      platform: '${json['platform'] ?? ''}',
      lastActive:
          DateTime.tryParse('${json['lastActive']}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      syncToken: token is String ? token : null,
    );
  }

  final String id;
  final String name;
  final String platform;
  final DateTime lastActive;
  final String? syncToken;

  bool get revoked => syncToken == null || syncToken!.isEmpty;

  ConnectedDevice revoke() => ConnectedDevice(
    id: id,
    name: name,
    platform: platform,
    lastActive: lastActive,
    syncToken: null,
  );
}

/// Reads and revokes phones registered for this account.
class SyncDeviceDirectory {
  const SyncDeviceDirectory._();

  static const path = '/api/sync/devices';

  static Future<List<ConnectedDevice>> fetch({
    Future<Map<String, Object?>?> Function()? get,
  }) async {
    final raw = await (get ?? _get)();
    final devices = raw?['devices'];
    if (devices is! List) return const [];
    return [
      for (final row in devices)
        if (row is Map) ConnectedDevice.fromJson(Map<String, Object?>.from(row)),
    ];
  }

  static Future<void> remove(
    String id, {
    Future<bool> Function(String id)? delete,
  }) async {
    final ok = await (delete ?? _delete)(id);
    if (!ok) {
      throw StateError('This device could not be removed.');
    }
  }

  static Future<void> registerCurrent() async {
    if (!AppServices.isInitialized) return;
    final id = await AppServices.instance.deviceIds.getOrCreate();
    await AppServices.instance.httpTransport.post(
      path,
      body: {
        'id': id,
        'name': 'This phone',
        'platform': defaultTargetPlatform.name,
      },
    );
  }

  static Future<Map<String, Object?>?> _get() async {
    if (!AppServices.isInitialized) return null;
    final result = await AppServices.instance.httpTransport.get(path);
    final response = result.valueOrNull;
    if (response == null || response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  }

  static Future<bool> _delete(String id) async {
    if (!AppServices.isInitialized) return false;
    final result = await AppServices.instance.httpTransport.delete('$path/$id');
    final response = result.valueOrNull;
    return response != null && response.statusCode == 200;
  }
}

/// Re-wraps the account key. Existing journal ciphertext stays as it is.
class SyncPassphraseRotation {
  const SyncPassphraseRotation._();

  static Future<void> rotate({
    required String currentPassphrase,
    required String nextPassphrase,
    Future<void> Function(AccountKeyBundle bundle)? publish,
  }) async {
    final bundle = await AccountSyncKey.readBundle();
    if (bundle == null) throw const AccountKeyUnlockFailed();
    final wrapped = await AccountSyncKey.changePassphrase(
      wrapped: bundle.wrappedByPassphrase,
      currentPassphrase: currentPassphrase,
      nextPassphrase: nextPassphrase,
    );
    final next = AccountKeyBundle(
      wrappedByPassphrase: wrapped,
      wrappedByRecovery: bundle.wrappedByRecovery,
      createdAt: bundle.createdAt,
    );
    await AccountSyncKey.storeBundle(next);
    await E2eeSyncSettings.storeInVault(nextPassphrase);
    await (publish ?? AccountSyncKeyImport.publish)(next);
  }
}

/// Relative sync line, for example "Synced 2 min ago · 3 devices".
String syncStatusLine({
  required DateTime? syncedAt,
  required int deviceCount,
  required DateTime now,
}) {
  final devices = deviceCount == 1 ? '1 device' : '$deviceCount devices';
  if (syncedAt == null) return 'Not synced yet · $devices';
  final minutes = now.difference(syncedAt).inMinutes;
  if (minutes < 1) return 'Synced just now · $devices';
  if (minutes < 60) return 'Synced $minutes min ago · $devices';
  final hours = minutes ~/ 60;
  final hourLabel = hours == 1 ? '1 hr ago' : '$hours hr ago';
  return 'Synced $hourLabel · $devices';
}

/// Status line and the phones that hold a sync token.
class SyncStatusView extends StatefulWidget {
  const SyncStatusView({
    required this.syncedAt,
    required this.devices,
    this.now,
    this.loadDevices,
    this.removeDevice,
    this.changePassphrase,
    this.embedded = false,
    super.key,
  });

  final DateTime? syncedAt;
  final List<ConnectedDevice> devices;
  final DateTime? now;
  final Future<List<ConnectedDevice>> Function()? loadDevices;
  final Future<void> Function(String id)? removeDevice;
  final Future<void> Function({
    required String currentPassphrase,
    required String nextPassphrase,
  })?
  changePassphrase;
  final bool embedded;

  @override
  State<SyncStatusView> createState() => _SyncStatusViewState();
}

class _SyncStatusViewState extends State<SyncStatusView> {
  late List<ConnectedDevice> _devices = List<ConnectedDevice>.of(
    widget.devices,
  );
  final _currentPassphrase = TextEditingController();
  final _nextPassphrase = TextEditingController();
  String? _passphraseMessage;

  int get _active => _devices.where((device) => !device.revoked).length;

  @override
  void initState() {
    super.initState();
    final load = widget.loadDevices;
    if (load == null) return;
    unawaited(
      load().then((devices) {
        if (mounted) setState(() => _devices = devices);
      }),
    );
  }

  @override
  void dispose() {
    _currentPassphrase.dispose();
    _nextPassphrase.dispose();
    super.dispose();
  }

  Future<void> _revoke(ConnectedDevice device) async {
    final remove = widget.removeDevice;
    if (remove != null) {
      try {
        await remove(device.id);
      } on Object {
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _devices = [
        for (final row in _devices)
          if (row.id == device.id) row.revoke() else row,
      ];
    });
  }

  Future<void> _rotate() async {
    final change = widget.changePassphrase;
    if (change == null) return;
    final current = _currentPassphrase.text.trim();
    final next = _nextPassphrase.text.trim();
    if (current.isEmpty || next.isEmpty) return;
    try {
      await change(currentPassphrase: current, nextPassphrase: next);
      if (!mounted) return;
      setState(() => _passphraseMessage = 'Passphrase updated.');
    } on Object {
      if (!mounted) return;
      setState(() => _passphraseMessage = 'That passphrase could not be changed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = syncStatusLine(
      syncedAt: widget.syncedAt,
      deviceCount: _active,
      now: widget.now ?? DateTime.now(),
    );
    final body = ListView(
      padding: const EdgeInsets.all(20),
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      children: [
        Text(line, key: const Key('sync_status_bar')),
        const SizedBox(height: 16),
        for (final device in _devices)
          ListTile(
            key: Key('sync_device_${device.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(device.name),
            subtitle: Text(
              [
                if (device.platform.isNotEmpty) device.platform,
                device.lastActive.toUtc().toIso8601String(),
              ].join(' · '),
            ),
            trailing: device.revoked
                ? const Text('Removed')
                : TextButton(
                    key: Key('revoke_device_${device.id}'),
                    onPressed: () => unawaited(_revoke(device)),
                    child: const Text('Revoke / Remove Device'),
                  ),
          ),
        if (widget.changePassphrase != null) ...[
          const SizedBox(height: 24),
          TextField(
            key: const Key('sync_current_passphrase'),
            controller: _currentPassphrase,
            decoration: const InputDecoration(labelText: 'Current passphrase'),
          ),
          TextField(
            key: const Key('sync_next_passphrase'),
            controller: _nextPassphrase,
            decoration: const InputDecoration(labelText: 'New passphrase'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('sync_change_passphrase'),
            onPressed: () => unawaited(_rotate()),
            child: const Text('Change passphrase'),
          ),
          if (_passphraseMessage != null) Text(_passphraseMessage!),
        ],
      ],
    );
    if (widget.embedded) {
      return KeyedSubtree(key: const Key('sync_status_view'), child: body);
    }
    return Scaffold(
      key: const Key('sync_status_view'),
      appBar: AppBar(title: const Text('Sync')),
      body: body,
    );
  }
}
