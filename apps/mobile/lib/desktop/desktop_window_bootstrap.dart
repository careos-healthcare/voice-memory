import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/desktop/desktop_window_state.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

/// Native desktop window size, integrated title bar, and frame persistence.
class DesktopWindowBootstrap with WindowListener {
  DesktopWindowBootstrap._();

  static final DesktopWindowBootstrap instance = DesktopWindowBootstrap._();

  DesktopWindowStateStore? _store;
  var _started = false;

  static bool get isDesktopHost {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  Future<void> initialize() async {
    if (!isDesktopHost || _started) return;
    _started = true;
    try {
      await windowManager.ensureInitialized();
      final support = await getApplicationSupportDirectory();
      _store = DesktopWindowStateStore(
        File('${support.path}/desktop_window_state.json'),
      );
      final restored = await _store!.load();
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
      windowManager.addListener(this);
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'Desktop window setup skipped',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void onWindowMoved() {
    _persist();
  }

  @override
  void onWindowResized() {
    _persist();
  }

  void _persist() {
    unawaited(_saveFrame());
  }

  Future<void> _saveFrame() async {
    final store = _store;
    if (store == null) return;
    try {
      final bounds = await windowManager.getBounds();
      await store.save(
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
