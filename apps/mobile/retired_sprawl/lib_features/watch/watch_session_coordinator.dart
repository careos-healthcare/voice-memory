import 'dart:async';

import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_ingest_service.dart';
import 'package:archiveme_mobile/features/watch_companion/watch_connectivity_service.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/foundation.dart';

/// Boots the iOS watch audio inbox and optionally forwards captures into ingest.
class WatchSessionCoordinator {
  WatchSessionCoordinator({
    WatchConnectivityService? connectivity,
    WatchAudioIngestService? ingestService,
  }) : _connectivity = connectivity ?? WatchConnectivityService(),
       _ingestService = ingestService;

  final WatchConnectivityService _connectivity;
  final WatchAudioIngestService? _ingestService;

  WatchAudioIngestService? get ingestService =>
      _ingestService ??
      (AppServices.isInitialized ? AppServices.instance.watchAudioIngest : null);

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final ingest = ingestService;
    await _connectivity.connect(
      onCapture: ingest == null ? null : (capture) => unawaited(ingest.enqueue(capture)),
    );
  }

  /// Test hook for injecting a capture without native WCSession.
  @visibleForTesting
  Future<void> ingestCaptureForTest(WatchAudioCapture capture) async {
    final ingest = ingestService;
    if (ingest == null) return;
    await ingest.enqueue(capture);
  }

  void dispose() {
    _connectivity.dispose();
  }
}