import 'dart:async';

import 'package:archiveme_mobile/features/capture/audio/background_capture_service.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/features/capture/deep_link/capture_widget_deep_link.dart';
import 'package:archiveme_mobile/features/capture/storage/capture_audio_metadata_store.dart';
import 'package:archiveme_mobile/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final captureModuleRuntimeConfigProvider =
    Provider<CaptureModuleRuntimeConfig?>((ref) {
      return CaptureModuleRuntimeConfig.instance;
    });

final captureAudioMetadataStoreProvider = Provider<CaptureAudioMetadataStore?>(
  (ref) {
    final config = ref.watch(captureModuleRuntimeConfigProvider);
    if (config == null) return null;
    return CaptureAudioMetadataStore(
      sqliteFilePath: config.sqliteFilePath,
      encryptionPassword: config.encryptionPassword,
      keyAlias: config.keyAlias,
    );
  },
);

final captureWidgetDeepLinkHandlerProvider = Provider<CaptureWidgetDeepLinkHandler>(
  (ref) {
    final handler = CaptureWidgetDeepLinkHandler();
    ref.onDispose(handler.dispose);
    return handler;
  },
);

final backgroundCaptureServiceProvider = Provider<BackgroundCaptureService?>((ref) {
  final config = ref.watch(captureModuleRuntimeConfigProvider);
  if (config == null) return null;
  return BackgroundCaptureService(config: config);
});

/// Wires widget/deep-link URIs to background capture + navigation.
final captureModuleListenerProvider = Provider<void>((ref) {
  final deepLinkHandler = ref.watch(captureWidgetDeepLinkHandlerProvider);
  unawaited(deepLinkHandler.initialize());

  final subscription = deepLinkHandler.uriStream.listen((uri) {
    unawaited(_handleRecordDeepLink(ref, uri));
  });

  ref.onDispose(subscription.cancel);
});

Future<void> bindCaptureModuleRuntime(CaptureModuleRuntimeConfig config) async {
  CaptureModuleRuntimeConfig.instance = config;
}

Future<void> _handleRecordDeepLink(Ref ref, Uri uri) async {
  if (!CaptureWidgetDeepLinkHandler.isRecordDeepLink(uri)) return;

  final captureService = ref.read(backgroundCaptureServiceProvider);
  if (captureService != null) {
    await captureService.startBackgroundCapture();
  }

  final context = appRouter.routerDelegate.navigatorKey.currentContext;
  if (context != null && context.mounted) {
    context.go(CaptureDeepLinkUris.recordLaunchRoute);
  }
}
