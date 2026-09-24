import 'package:archiveme_mobile/desktop/desktop_window_host.dart';

/// Native desktop window size, integrated title bar, and frame persistence.
///
/// `window_manager` stays inside [DesktopWindowHost] so phone and web builds
/// never import it.
class DesktopWindowBootstrap {
  DesktopWindowBootstrap._();

  static final DesktopWindowBootstrap instance = DesktopWindowBootstrap._();

  static bool get isDesktopHost => DesktopWindowHost.isDesktopHost;

  Future<void> initialize() => DesktopWindowHost.initialize();
}
