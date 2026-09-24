import 'package:archiveme_mobile/features/desktop/desktop_drop_ingestion.dart';
import 'package:archiveme_mobile/router/primary_destination.dart';
import 'package:archiveme_mobile/features/desktop/desktop_master_detail_layout.dart';
import 'package:archiveme_mobile/features/desktop/desktop_shortcut_manager.dart';
import 'package:flutter/material.dart';

/// Wide ArchiveMe window: three columns, hotkeys, and file drop.
class DesktopWorkspace extends StatefulWidget {
  const DesktopWorkspace({
    required this.moments,
    required this.onNewRecording,
    super.key,
    this.onFiles,
    this.enableFileDrop,
  });

  final List<DesktopMoment> moments;
  final VoidCallback onNewRecording;
  final Future<void> Function(List<DesktopDroppedFile> files)? onFiles;
  final bool? enableFileDrop;

  @override
  State<DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<DesktopWorkspace> {
  final _searchFocus = FocusNode();
  final _playback = DesktopPlaybackController();
  var _section = 'Archive';

  @override
  void dispose() {
    _searchFocus.dispose();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopDropIngestion(
      enablePlugin: widget.enableFileDrop,
      onFiles: widget.onFiles ?? _ignoreFiles,
      child: DesktopShortcutManager(
        searchFocus: _searchFocus,
        onNewRecording: widget.onNewRecording,
        onTogglePlayback: _playback.toggle,
        child: DesktopArchiveColumns(
          moments: widget.moments,
          playback: _playback,
          searchFocus: _searchFocus,
          destinations: [
            for (final destination in PrimaryDestination.shellValues)
              DesktopNavDestination(
                label: destination.label,
                selected: destination.label == _section,
                onTap: () => setState(() => _section = destination.label),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _ignoreFiles(List<DesktopDroppedFile> files) async {}
}
