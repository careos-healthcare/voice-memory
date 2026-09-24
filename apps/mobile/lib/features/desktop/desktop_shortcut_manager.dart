import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for a new voice or text moment.
class NewDesktopRecordingIntent extends Intent {
  const NewDesktopRecordingIntent();
}

/// Moves focus to the semantic search field.
class FocusDesktopSearchIntent extends Intent {
  const FocusDesktopSearchIntent();
}

/// Opens the export dialog.
class UniversalExportIntent extends Intent {
  const UniversalExportIntent();
}

/// Plays or pauses the selected moment.
class ToggleDesktopPlaybackIntent extends Intent {
  const ToggleDesktopPlaybackIntent();
}

/// Whether the selected moment is playing.
class DesktopPlaybackController extends ChangeNotifier {
  String? momentId;
  bool hasAudio = false;
  bool playing = false;

  void select(String? id, {bool hasAudio = false}) {
    if (momentId == id && this.hasAudio == hasAudio) return;
    momentId = id;
    this.hasAudio = hasAudio;
    playing = false;
    notifyListeners();
  }

  void toggle() {
    if (momentId == null || !hasAudio) return;
    playing = !playing;
    notifyListeners();
  }
}

/// Cmd/Ctrl shortcuts for recording, search, export, and playback.
class DesktopShortcutManager extends StatelessWidget {
  const DesktopShortcutManager({
    required this.child,
    required this.onNewRecording,
    required this.onTogglePlayback,
    super.key,
    this.searchFocus,
    this.onFocusSearch,
    this.onUniversalExport,
  });

  final Widget child;
  final VoidCallback onNewRecording;
  final VoidCallback onTogglePlayback;
  final FocusNode? searchFocus;
  final VoidCallback? onFocusSearch;
  final VoidCallback? onUniversalExport;

  static const Map<ShortcutActivator, Intent> bindings = {
    SingleActivator(LogicalKeyboardKey.keyN, meta: true):
        NewDesktopRecordingIntent(),
    SingleActivator(LogicalKeyboardKey.keyN, control: true):
        NewDesktopRecordingIntent(),
    SingleActivator(LogicalKeyboardKey.keyF, meta: true):
        FocusDesktopSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyF, control: true):
        FocusDesktopSearchIntent(),
    SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true):
        UniversalExportIntent(),
    SingleActivator(LogicalKeyboardKey.keyE, control: true, shift: true):
        UniversalExportIntent(),
    SingleActivator(LogicalKeyboardKey.space): ToggleDesktopPlaybackIntent(),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: bindings,
      child: Actions(
        actions: {
          NewDesktopRecordingIntent: CallbackAction<NewDesktopRecordingIntent>(
            onInvoke: (_) {
              onNewRecording();
              return null;
            },
          ),
          FocusDesktopSearchIntent: CallbackAction<FocusDesktopSearchIntent>(
            onInvoke: (_) {
              searchFocus?.requestFocus();
              onFocusSearch?.call();
              return null;
            },
          ),
          UniversalExportIntent: CallbackAction<UniversalExportIntent>(
            onInvoke: (_) {
              onUniversalExport?.call();
              unawaited(showUniversalExportDialog(context));
              return null;
            },
          ),
          ToggleDesktopPlaybackIntent:
              CallbackAction<ToggleDesktopPlaybackIntent>(
                onInvoke: (_) {
                  if (_typing()) return null;
                  onTogglePlayback();
                  return null;
                },
              ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  bool _typing() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}

/// Export dialog opened from the keyboard.
Future<void> showUniversalExportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('universal_export_dialog'),
        title: const Text('Export archive'),
        content: const Text('Save a copy of your moments on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
