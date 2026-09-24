import 'package:archiveme_mobile/desktop/desktop_window_host_stub.dart'
    if (dart.library.io) 'package:archiveme_mobile/desktop/desktop_window_host_io.dart'
    as host;
import 'package:flutter/widgets.dart';

/// Desktop title bar. Mobile and web builds use a no-op host.
class DesktopWindowHost {
  const DesktopWindowHost._();

  static bool get isDesktopHost => host.desktopWindowIsHost;

  static Future<void> initialize() => host.initializeDesktopWindow();

  static Widget chrome() => host.desktopWindowChrome();
}
