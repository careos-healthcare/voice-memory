import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/desktop/desktop_window_state.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

/// True only for a desktop process that is not a widget test.
bool get desktopWindowIsHost {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// Hidden title bar with drag on macOS and caption buttons on Windows and Linux.
Widget desktopWindowChrome() {
  if (!desktopWindowIsHost) return const SizedBox.shrink();
  return const _DesktopWindowChrome();
}

class _DesktopWindowChrome extends StatelessWidget {
  const _DesktopWindowChrome();

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return const SizedBox(
        key: Key('desktop_window_drag_region'),
        height: 28,
        width: double.infinity,
        child: DragToMoveArea(child: SizedBox.expand()),
      );
    }
    return WindowCaption(
      key: const Key('desktop_window_caption'),
      brightness: Theme.of(context).brightness,
      backgroundColor: AppColors.backgroundPrimary,
      title: const Text(AppConfig.appName),
    );
  }
}

Future<void> initializeDesktopWindow() async {
  if (!desktopWindowIsHost) return;
  try {
    await windowManager.ensureInitialized();
    final support = await getApplicationSupportDirectory();
    final store = DesktopWindowStateStore(
      File('${support.path}/desktop_window_state.json'),
    );
    final restored = await store.load();
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: restored?.size ?? DesktopWindowState.defaultSize,
        minimumSize: DesktopWindowState.minimumSize,
        center: restored == null,
        title: AppConfig.appName,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: true,
      ),
      () async {
        if (restored != null) {
          await windowManager.setBounds(restored.bounds);
        }
        await windowManager.show();
        await windowManager.focus();
      },
    );
    windowManager.addListener(_FrameListener(store));
  } on Object catch (error, stackTrace) {
    AppLogger.debug(
      'Desktop window setup skipped',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class _FrameListener extends WindowListener {
  _FrameListener(this._store);

  final DesktopWindowStateStore _store;

  @override
  void onWindowMoved() => unawaited(_save());

  @override
  void onWindowResized() => unawaited(_save());

  Future<void> _save() async {
    try {
      final bounds = await windowManager.getBounds();
      await _store.save(
        DesktopWindowState(
          x: bounds.left,
          y: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Desktop window state was not saved',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
