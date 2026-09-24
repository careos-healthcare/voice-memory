import 'package:archiveme_mobile/desktop/desktop_window_host.dart';
import 'package:flutter/material.dart';

/// Drag region and, on Windows and Linux, caption buttons for the hidden title bar.
class DesktopWindowChrome extends StatelessWidget {
  const DesktopWindowChrome({super.key});

  static bool get isEnabled => DesktopWindowHost.isDesktopHost;

  @override
  Widget build(BuildContext context) => DesktopWindowHost.chrome();
}
