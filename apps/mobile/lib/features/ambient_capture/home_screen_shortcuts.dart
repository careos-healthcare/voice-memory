import 'dart:io';

import 'package:archiveme_mobile/features/ambient_capture/ambient_capture_router.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// Home-screen icon shortcuts for voice and text capture.
abstract final class HomeScreenShortcuts {
  HomeScreenShortcuts._();

  static const newVoiceEntry = 'new_voice_entry';
  static const quickText = 'quick_text';

  static const items = <ShortcutItem>[
    ShortcutItem(
      type: newVoiceEntry,
      localizedTitle: 'New Voice Entry',
      icon: 'ic_shortcut_voice',
    ),
    ShortcutItem(
      type: quickText,
      localizedTitle: 'Quick Text',
      icon: 'ic_shortcut_text',
    ),
  ];

  /// Capture route for a shortcut type from the `quick_actions` plugin.
  static String? locationFor(String? type) {
    return switch (type) {
      newVoiceEntry => CaptureDeepLinkUris.recordLaunchRoute,
      quickText => V1RouteRegistry.quickCapturePath,
      _ => null,
    };
  }

  /// Registers the two icon shortcuts and routes a tap into capture.
  static Future<void> register({QuickActions? actions}) async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    final plugin = actions ?? const QuickActions();
    try {
      await plugin.initialize((type) {
        final location = locationFor(type);
        if (location != null) AmbientCaptureRouter.go(location);
      });
      await plugin.setShortcutItems(items);
    } on Object {
      // Desktop builds have no home-screen shortcut surface.
    }
  }
}
