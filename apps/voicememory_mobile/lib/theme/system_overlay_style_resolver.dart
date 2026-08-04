import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// System bar styling for the very first frame, before any themed surface has
/// rendered.
///
/// The launch overlay used to be pinned to the light palette, which left a
/// white navigation bar under a dark app. Resolving it from the reported
/// platform brightness means the system chrome is correct from the first
/// frame; after that the app bar theme keeps it in step.
abstract final class SystemOverlayStyleResolver {
  static SystemUiOverlayStyle forBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark
        ? AppTheme.dark().scaffoldBackgroundColor
        : AppTheme.light().scaffoldBackgroundColor;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: surface,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static SystemUiOverlayStyle forPlatform() =>
      forBrightness(PlatformDispatcher.instance.platformBrightness);

  static void apply() => SystemChrome.setSystemUIOverlayStyle(forPlatform());
}
