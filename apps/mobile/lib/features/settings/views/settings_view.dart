import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/core/config/launch_profile.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/export/services/auto_backup_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cloud AI processing control. Local memory stays on either way.
class CloudAiProcessingToggle extends StatelessWidget {
  const CloudAiProcessingToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  static const title = 'Cloud AI Processing';

  static const subtitle =
      'Sends encrypted or plain-text transcripts to cloud language models for pattern recognition and weekly summaries. Local memory remains active regardless.';

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: const Key('settings_cloud_sync'),
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: ArchiveMobileTypography.listTitle(context)),
      subtitle: Text(
        subtitle,
        style: ArchiveMobileTypography.listSubtitle(context),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Weekly encrypted backup kept in the device's files.
class AutomaticWeeklyBackupToggle extends StatefulWidget {
  const AutomaticWeeklyBackupToggle({
    super.key,
    this.readEnabled,
    this.writeEnabled,
    this.onEnabled,
    this.readLastBackup,
    this.onBackupNow,
  });

  final Future<bool> Function()? readEnabled;
  final Future<void> Function(bool enabled)? writeEnabled;
  final Future<void> Function()? onEnabled;
  final Future<DateTime?> Function()? readLastBackup;
  final Future<void> Function()? onBackupNow;

  @override
  State<AutomaticWeeklyBackupToggle> createState() =>
      _AutomaticWeeklyBackupToggleState();
}

class _AutomaticWeeklyBackupToggleState
    extends State<AutomaticWeeklyBackupToggle> {
  var _enabled = true;
  var _ready = false;
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _read();
    final last = await _readLast();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _lastBackup = last;
      _ready = true;
    });
  }

  Future<DateTime?> _readLast() async {
    final injected = widget.readLastBackup;
    if (injected != null) return injected();
    if (!AppServices.isInitialized) return null;
    final raw = await AppServices.instance.prefs.readString(
      AutoBackupService.lastBackupKey,
    );
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _chooseFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose backup folder',
    );
    if (path == null || path.isEmpty || !AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeString(
      AutoBackupService.folderPreferenceKey,
      path,
    );
  }

  Future<void> _backupNow() async {
    final injected = widget.onBackupNow;
    if (injected != null) {
      await injected();
    } else {
      await AutoBackupService.runScheduled(force: true);
    }
    final last = await _readLast();
    if (mounted) setState(() => _lastBackup = last);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
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
        ),
        Text(
          AutoBackupService.statusLabel(_lastBackup, DateTime.now()),
          key: const Key('settings_backup_status'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('settings_backup_now'),
            onPressed: _ready ? () => unawaited(_backupNow()) : null,
            child: const Text('Back up now'),
          ),
        ),
        if (!kIsWeb && Platform.isAndroid)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('settings_backup_choose_folder'),
              onPressed: _ready ? () => unawaited(_chooseFolder()) : null,
              child: const Text('Choose backup folder'),
            ),
          ),
      ],
    );
  }
}
