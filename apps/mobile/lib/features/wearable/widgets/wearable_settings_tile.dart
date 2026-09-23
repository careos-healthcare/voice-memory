import 'package:archiveme_mobile/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Account row for watch connection, background sync, and the transfer queue.
class WearableSettingsTile extends StatelessWidget {
  const WearableSettingsTile({
    required this.connected,
    required this.backgroundSync,
    required this.pendingCount,
    required this.onBackgroundSyncChanged,
    super.key,
    this.confirmation,
  });

  final bool connected;
  final bool backgroundSync;
  final int pendingCount;
  final ValueChanged<bool> onBackgroundSyncChanged;
  final String? confirmation;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('wearable_settings_tile'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Wearable'),
          subtitle: Text(
            connected ? 'Connected' : 'Not connected',
            key: const Key('wearable_connection_status'),
          ),
        ),
        SwitchListTile(
          key: const Key('wearable_background_sync'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Battery-friendly background sync'),
          value: backgroundSync,
          onChanged: onBackgroundSyncChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spacing2),
          child: Text(
            wearablePendingLabel(pendingCount),
            key: const Key('wearable_pending_count'),
          ),
        ),
        if (confirmation != null)
          Text(
            confirmation!,
            key: const Key('wearable_confirmation'),
          ),
      ],
    );
  }
}

/// Queue copy such as "2 recordings waiting".
String wearablePendingLabel(int count) {
  if (count <= 0) return 'No recordings waiting';
  if (count == 1) return '1 recording waiting';
  return '$count recordings waiting';
}
