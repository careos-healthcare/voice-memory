import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_background_handler.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_store.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_shared_storage.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_widget_bridge.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_worker.dart';
import 'package:archiveme_mobile/sync/ulid.dart';

/// Coordinates widget shared storage → drift outbox → background pipeline.
class QuickCaptureWidgetService {
  QuickCaptureWidgetService({
    required QuickCaptureSharedStorage sharedStorage,
    required QuickCaptureOutboxStore outbox,
    required QuickCaptureBackgroundHandler backgroundHandler,
    QuickCaptureWidgetBridge? bridge,
  }) : _sharedStorage = sharedStorage,
       _outbox = outbox,
       _backgroundHandler = backgroundHandler,
       _bridge = bridge ?? const NoOpQuickCaptureWidgetBridge();

  final QuickCaptureSharedStorage _sharedStorage;
  final QuickCaptureOutboxStore _outbox;
  final QuickCaptureBackgroundHandler _backgroundHandler;
  final QuickCaptureWidgetBridge _bridge;

  static QuickCaptureWidgetService create({
    required QuickCaptureSharedStorage sharedStorage,
    required QuickCaptureOutboxStore outbox,
    required CapturePipelineService pipeline,
    BackgroundSyncQueueWorker? backgroundSyncWorker,
    QuickCaptureWidgetBridge? bridge,
  }) {
    return QuickCaptureWidgetService(
      sharedStorage: sharedStorage,
      outbox: outbox,
      bridge: bridge,
      backgroundHandler: QuickCaptureBackgroundHandler(
        outbox: outbox,
        pipeline: pipeline,
        backgroundSyncWorker: backgroundSyncWorker,
      ),
    );
  }

  /// Startup / background wake: ingest shared captures then process outbox.
  Future<QuickCaptureProcessResult> ingestAndProcessBackgroundQueue() async {
    await ingestSharedCaptures();
    final result = await _backgroundHandler.processPending();
    await refreshWidgetSnapshot(pendingCount: await _outbox.pendingCount());
    return result;
  }

  /// Moves widget / shortcut payloads from App Group storage into drift.
  Future<int> ingestSharedCaptures() async {
    final pending = await _sharedStorage.readPendingCaptures();
    if (pending.isEmpty) return 0;

    final acknowledged = <String>[];
    for (final payload in pending) {
      await _outbox.enqueue(payload);
      acknowledged.add(payload.captureId);
    }
    await _sharedStorage.acknowledgeCaptureIds(acknowledged);
    return acknowledged.length;
  }

  /// Enqueues a capture from an in-app quick action (tests / Android fallback).
  Future<String> enqueueCapture(QuickCaptureOutboxPayload payload) async {
    await _sharedStorage.enqueueLocalFallback(payload);
    return _outbox.enqueue(payload);
  }

  Future<String> enqueueTextNote(String text, {String source = 'quick_action'}) {
    return enqueueCapture(
      QuickCaptureOutboxPayload(
        captureId: generateUlid(),
        kind: QuickCaptureKind.text,
        text: text,
        source: source,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> refreshWidgetSnapshot({int pendingCount = 0}) async {
    if (!V1CapabilityRegistry.nativeExtensions) return;
    await _bridge.updateWidgetSnapshot({
      'title': 'Quick capture',
      'cta': pendingCount > 0 ? '$pendingCount queued' : 'Tap to capture',
      'route': V1RouteRegistry.quickCapturePath,
      'pendingCount': '$pendingCount',
    });
  }

  Future<String?> capturePendingLaunchRoute() async {
    return _sharedStorage.loadPendingLaunchRoute();
  }

  Future<void> clearPendingLaunchRoute() async {
    await _sharedStorage.clearPendingLaunchRoute();
  }

  /// Best-effort startup/resume hook: capture widget route, ingest, process.
  static Future<void> runStartupTasks() async {
    if (!V1CapabilityRegistry.nativeExtensions) return;
    if (!AppServices.isInitialized) return;
    final service = AppServices.instance.quickCaptureWidgetService;
    if (service == null) return;
    await service.capturePendingLaunchRoute();
    await service.ingestAndProcessBackgroundQueue();
  }
}
