import 'package:flutter/material.dart';

/// One phone that can sync this journal.
class ConnectedDevice {
  const ConnectedDevice({
    required this.id,
    required this.name,
    required this.lastActive,
    required this.syncToken,
  });

  final String id;
  final String name;
  final DateTime lastActive;
  final String? syncToken;

  bool get revoked => syncToken == null || syncToken!.isEmpty;

  ConnectedDevice revoke() => ConnectedDevice(
    id: id,
    name: name,
    lastActive: lastActive,
    syncToken: null,
  );
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
    super.key,
  });

  final DateTime? syncedAt;
  final List<ConnectedDevice> devices;
  final DateTime? now;

  @override
  State<SyncStatusView> createState() => _SyncStatusViewState();
}

class _SyncStatusViewState extends State<SyncStatusView> {
  late List<ConnectedDevice> _devices = List<ConnectedDevice>.of(
    widget.devices,
  );

  int get _active => _devices.where((device) => !device.revoked).length;

  @override
  Widget build(BuildContext context) {
    final line = syncStatusLine(
      syncedAt: widget.syncedAt,
      deviceCount: _active,
      now: widget.now ?? DateTime.now(),
    );
    return Scaffold(
      key: const Key('sync_status_view'),
      appBar: AppBar(title: const Text('Sync')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(line, key: const Key('sync_status_bar')),
          const SizedBox(height: 16),
          for (final device in _devices)
            ListTile(
              key: Key('sync_device_${device.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(device.name),
              subtitle: Text(device.lastActive.toUtc().toIso8601String()),
              trailing: device.revoked
                  ? const Text('Removed')
                  : TextButton(
                      key: Key('revoke_device_${device.id}'),
                      onPressed: () {
                        setState(() {
                          _devices = [
                            for (final row in _devices)
                              if (row.id == device.id) row.revoke() else row,
                          ];
                        });
                      },
                      child: const Text('Revoke / Remove Device'),
                    ),
            ),
        ],
      ),
    );
  }
}
