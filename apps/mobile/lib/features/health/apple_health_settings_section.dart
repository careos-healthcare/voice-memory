import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/health/apple_health_platform.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Apple Health controls. Hidden on Android and on iOS 17 and older.
class AppleHealthSettingsSection extends StatelessWidget {
  const AppleHealthSettingsSection({
    required this.readEnabled,
    required this.writeEnabled,
    required this.revoked,
    required this.onRead,
    required this.onWrite,
    this.onOpenSettings,
    super.key,
  });

  final bool readEnabled;
  final bool writeEnabled;
  final bool revoked;
  final ValueChanged<bool> onRead;
  final ValueChanged<bool> onWrite;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (!AppleHealthPlatform.supportsStateOfMind) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SwitchListTile(
          key: const Key('settings_health_mood_sync'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Apple Health',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          subtitle: Text(
            'Shows the State of Mind you logged beside the moment from that day.',
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          value: readEnabled && !revoked,
          onChanged: onRead,
        ),
        SwitchListTile(
          key: const Key('settings_health_mood_write'),
          contentPadding: const EdgeInsets.only(left: 16),
          title: Text(
            'Save my moods to Apple Health',
            style: ArchiveMobileTypography.listTitle(context),
          ),
          subtitle: Text(
            'Writes the mood you pick in Thoughtprint.',
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          value: writeEnabled && !revoked,
          onChanged: onWrite,
        ),
        if (revoked)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('settings_health_settings_link'),
              onPressed: onOpenSettings ?? openAppSettings,
              child: const Text('Health settings'),
            ),
          ),
      ],
    );
  }
}
