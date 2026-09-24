import 'package:archiveme_mobile/router/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens a capture route once the root navigator exists.
///
/// A cold start from an icon shortcut or a widget can arrive before the first
/// frame. The location is kept until [flush] runs from the mounted shell.
abstract final class AmbientCaptureRouter {
  AmbientCaptureRouter._();

  static String? pendingLocation;

  static void go(String location) {
    final context = appRootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      pendingLocation = location;
      return;
    }
    pendingLocation = null;
    context.go(location);
  }

  static void flush() {
    final location = pendingLocation;
    if (location == null) return;
    go(location);
  }
}
