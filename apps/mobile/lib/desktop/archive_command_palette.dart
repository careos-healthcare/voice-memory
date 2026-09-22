import 'dart:async';

import 'package:archiveme_mobile/core/theme/theme_preference.dart';
import 'package:archiveme_mobile/desktop/archive_command_catalog.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens the command palette on the root navigator.
Future<void> showArchiveCommandPalette({
  GlobalKey<NavigatorState>? navigatorKey,
  void Function(ArchiveCommand command)? onSelected,
}) {
  final context = (navigatorKey ?? appRootNavigatorKey).currentContext;
  if (context == null) return Future<void>.value();
  return showDialog<void>(
    context: context,
    builder: (context) => ArchiveCommandPalette(onSelected: onSelected),
  );
}

/// Keyboard-first command list: filter, arrows, enter.
class ArchiveCommandPalette extends StatefulWidget {
  const ArchiveCommandPalette({super.key, this.onSelected});

  final void Function(ArchiveCommand command)? onSelected;

  @override
  State<ArchiveCommandPalette> createState() => _ArchiveCommandPaletteState();
}

class _ArchiveCommandPaletteState extends State<ArchiveCommandPalette> {
  final _query = TextEditingController();
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      if (_index != 0) setState(() => _index = 0);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<ArchiveCommand> get _results =>
      ArchiveCommandCatalog.filter(_query.text);

  void _move(int delta) {
    final results = _results;
    if (results.isEmpty) return;
    setState(() {
      _index = (_index + delta).clamp(0, results.length - 1);
    });
  }

  void _activate() {
    final results = _results;
    if (results.isEmpty) return;
    final command = results[_index.clamp(0, results.length - 1)];
    final custom = widget.onSelected;
    if (custom != null) {
      custom(command);
    } else if (command.kind == ArchiveCommandKind.toggleTheme) {
      ThemePreference.instance.toggle();
    } else {
      appRouter.go(command.route);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Dialog(
      key: const Key('archive_command_palette'),
      backgroundColor: AppColors.backgroundSecondary,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowDown): _PaletteDownIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): _PaletteUpIntent(),
            SingleActivator(LogicalKeyboardKey.enter): _PaletteActivateIntent(),
          },
          child: Actions(
            actions: {
              _PaletteDownIntent: CallbackAction<_PaletteDownIntent>(
                onInvoke: (_) {
                  _move(1);
                  return null;
                },
              ),
              _PaletteUpIntent: CallbackAction<_PaletteUpIntent>(
                onInvoke: (_) {
                  _move(-1);
                  return null;
                },
              ),
              _PaletteActivateIntent: CallbackAction<_PaletteActivateIntent>(
                onInvoke: (_) {
                  _activate();
                  return null;
                },
              ),
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('archive_command_palette_query'),
                    controller: _query,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search or jump…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _activate(),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final command = results[index];
                        final selected = index == _index;
                        return ListTile(
                          key: Key('archive_command_${command.id}'),
                          selected: selected,
                          title: Text(command.title),
                          subtitle: Text(command.subtitle),
                          onTap: () {
                            setState(() => _index = index);
                            _activate();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteDownIntent extends Intent {
  const _PaletteDownIntent();
}

class _PaletteUpIntent extends Intent {
  const _PaletteUpIntent();
}

class _PaletteActivateIntent extends Intent {
  const _PaletteActivateIntent();
}

/// Listens for Cmd+K and Ctrl+K anywhere in the app.
class CommandPaletteHost extends StatefulWidget {
  const CommandPaletteHost({
    required this.child,
    super.key,
    this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<CommandPaletteHost> createState() => _CommandPaletteHostState();
}

class _CommandPaletteHostState extends State<CommandPaletteHost> {
  var _open = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyK) return false;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final shortcut =
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
    if (!shortcut) return false;
    final nav = widget.navigatorKey ?? appRootNavigatorKey;
    if (_open) {
      final navContext = nav.currentContext;
      if (navContext != null && Navigator.of(navContext).canPop()) {
        Navigator.of(navContext).pop();
      }
      _open = false;
      return true;
    }
    if (_editableTextFocused) return false;
    if (nav.currentContext == null) return false;
    _open = true;
    unawaited(
      showArchiveCommandPalette(navigatorKey: nav).whenComplete(() {
        _open = false;
      }),
    );
    return true;
  }

  bool get _editableTextFocused {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
