import 'dart:io';

import 'package:archiveme_mobile/config/app_config.dart';
import 'package:archiveme_mobile/desktop/desktop_window_bootstrap.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Drag region and, on Windows and Linux, caption buttons for the hidden title bar.
class DesktopWindowChrome extends StatelessWidget {
  const DesktopWindowChrome({super.key});

  static bool get isEnabled => DesktopWindowBootstrap.isDesktopHost;

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return const SizedBox.shrink();
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
