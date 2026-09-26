import 'package:archiveme_mobile/core/config/launch_profile.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/export/services/auto_backup_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';

/// Weekly encrypted backup kept in the device's files.
class AutomaticWeeklyBackupToggle extends StatefulWidget {
  const AutomaticWeeklyBackupToggle({
    super.key,
    this.readEnabled,
    this.writeEnabled,
    this.onEnabled,
  });

  final Future<bool> Function()? readEnabled;
  final Future<void> Function(bool enabled)? writeEnabled;
  final Future<void> Function()? onEnabled;

  @override
  State<AutomaticWeeklyBackupToggle> createState() =>
      _AutomaticWeeklyBackupToggleState();
}

class _AutomaticWeeklyBackupToggleState
    extends State<AutomaticWeeklyBackupToggle> {
  var _enabled = true;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _read();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _ready = true;
    });
  }

  Future<bool> _read() async {
    final injected = widget.readEnabled;
    if (injected != null) return injected();
    if (!AppServices.isInitialized) return true;
    return await AppServices.instance.prefs.readBool(
          AutoBackupService.preferenceKey,
        ) ??
        true;
  }

  Future<void> _write(bool enabled) async {
    final injected = widget.writeEnabled;
    if (injected != null) {
      await injected(enabled);
      return;
    }
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeBool(
      AutoBackupService.preferenceKey,
      enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!LaunchProfile.AUTO_ENCRYPTED_BACKUP) return const SizedBox.shrink();
    return SwitchListTile(
      key: const Key('settings_auto_encrypted_backup'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Automatic Weekly Backup',
        style: ArchiveMobileTypography.listTitle(context),
      ),
      subtitle: Text(
        'Saves a fully encrypted copy of your journal and media to your device files every week.',
        style: ArchiveMobileTypography.listSubtitle(context),
      ),
      value: _enabled,
      onChanged: _ready
          ? (value) async {
              setState(() => _enabled = value);
              await _write(value);
              if (value) await widget.onEnabled?.call();
            }
          : null,
    );
  }
}
