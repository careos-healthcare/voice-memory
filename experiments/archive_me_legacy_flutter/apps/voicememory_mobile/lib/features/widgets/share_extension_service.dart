import 'dart:async';

import '../../services/local_storage/shared_vault_storage.dart';

typedef SharedVaultPayloadIngestor =
    Future<bool> Function(SharedVaultPayload payload);

class ShareExtensionService {
  ShareExtensionService({required this.storage, required this.platform});

  final SharedVaultStorage storage;
  final SharedVaultPlatformBridge platform;
  final StreamController<int> _pendingController =
      StreamController<int>.broadcast();
  bool _draining = false;
  bool _processingOutbox = false;
  StreamSubscription<SharedVaultPlatformEvent>? _nativeEventSubscription;
  SharedVaultPayloadIngestor? _foregroundIngestor;
  Future<void> _foregroundTail = Future<void>.value();

  Stream<int> get pendingCounts => _pendingController.stream;
  int get pendingCount => storage.pendingCount;

  void startForegroundProcessing(SharedVaultPayloadIngestor ingest) {
    _foregroundIngestor = ingest;
    if (_nativeEventSubscription != null ||
        platform is! SharedVaultPlatformEventSource) {
      return;
    }
    _nativeEventSubscription = (platform as SharedVaultPlatformEventSource)
        .events
        .listen((event) {
          if (event.type == SharedVaultPlatformEventType.shareReady) {
            _foregroundTail = _foregroundTail
                .then((_) => _processForegroundShare())
                .onError((_, _) {});
          }
        });
  }

  Future<void> _processForegroundShare() async {
    final ingest = _foregroundIngestor;
    if (ingest == null) return;
    await importPendingNativeShares();
    await drainTo(ingest);
  }

  Future<int> importPendingNativeShares() async {
    if (_draining) return 0;
    _draining = true;
    try {
      final imported = await storage.importNativeInbox(platform);
      _pendingController.add(storage.pendingCount);
      return imported;
    } finally {
      _draining = false;
    }
  }

  Future<List<SharedVaultPayload>> pending({int limit = 32}) =>
      storage.pending(limit: limit);

  Future<void> markProcessed(String payloadId) async {
    await storage.markProcessed(payloadId);
    _pendingController.add(storage.pendingCount);
  }

  Future<void> markAttempted(String payloadId) =>
      storage.markAttempted(payloadId);

  Future<int> drainTo(
    SharedVaultPayloadIngestor ingest, {
    int limit = 16,
  }) async {
    if (_processingOutbox) return 0;
    _processingOutbox = true;
    try {
      var processed = 0;
      for (final payload in await pending(limit: limit)) {
        try {
          if (!await ingest(payload)) {
            await markAttempted(payload.id);
            continue;
          }
          await markProcessed(payload.id);
          processed++;
        } on Object {
          await markAttempted(payload.id);
        } finally {
          payload.bytes?.fillRange(0, payload.bytes!.length, 0);
        }
      }
      return processed;
    } finally {
      _processingOutbox = false;
    }
  }

  Future<void> dispose() async {
    await _nativeEventSubscription?.cancel();
    await _foregroundTail;
    await _pendingController.close();
  }
}
