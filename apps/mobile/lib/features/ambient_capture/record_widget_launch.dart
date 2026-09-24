import 'dart:async';
import 'dart:io';

import 'package:archiveme_mobile/features/ambient_capture/ambient_capture_router.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// `home_widget` launch URI for the recording screen.
///
/// The `homeWidget` query is what the plugin uses to report the tap.
abstract final class RecordWidgetLaunch {
  RecordWidgetLaunch._();

  static final Uri recordUri = Uri(
    scheme: CaptureDeepLinkUris.scheme,
    host: CaptureDeepLinkUris.recordHost,
    queryParameters: const {'homeWidget': ''},
  );

  static bool isRecordLaunch(Uri? uri) {
    if (uri == null) return false;
    return uri.scheme.toLowerCase() == CaptureDeepLinkUris.scheme &&
        uri.host.toLowerCase() == CaptureDeepLinkUris.recordHost;
  }

  static StreamSubscription<Uri?>? _clicks;

  /// Sends a lock-screen or home-screen widget tap to the recording route.
  static Future<void> bind() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await _clicks?.cancel();
      _clicks = HomeWidget.widgetClicked.listen((uri) {
        if (!isRecordLaunch(uri)) return;
        AmbientCaptureRouter.go(CaptureDeepLinkUris.recordLaunchRoute);
      });
      final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (isRecordLaunch(initial)) {
        AmbientCaptureRouter.go(CaptureDeepLinkUris.recordLaunchRoute);
      }
    } on Object {
      // The plugin is absent on desktop.
    }
  }
}
