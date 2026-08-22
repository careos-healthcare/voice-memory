import 'dart:async';

import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:home_widget/home_widget.dart';

/// Parses widget / lock-screen URIs and exposes instant-record intents.
class CaptureWidgetDeepLinkHandler {
  CaptureWidgetDeepLinkHandler({
    this.appGroupId = 'group.com.voicememory.mobile',
  });

  final String appGroupId;

  final StreamController<Uri> _uriController = StreamController<Uri>.broadcast();

  Stream<Uri> get uriStream => _uriController.stream;

  bool _listening = false;

  static bool isRecordDeepLink(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != CaptureDeepLinkUris.scheme) return false;
    final host = uri.host.toLowerCase();
    if (host == CaptureDeepLinkUris.recordHost) return true;
    final path = uri.path.replaceFirst(RegExp('^/+'), '').toLowerCase();
    return path == CaptureDeepLinkUris.recordHost ||
        uri.toString().toLowerCase() == CaptureDeepLinkUris.recordUri;
  }

  Future<void> initialize() async {
    if (_listening) return;
    _listening = true;

    if (HomeWidget.groupId == null) {
      await HomeWidget.setAppGroupId(appGroupId);
    }

    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _emitIfRecord(initialUri);

    HomeWidget.widgetClicked.listen(_emitIfRecord);
  }

  void _emitIfRecord(Uri? uri) {
    if (!isRecordDeepLink(uri)) return;
    _uriController.add(uri!);
  }

  Future<void> dispose() async {
    await _uriController.close();
  }
}
