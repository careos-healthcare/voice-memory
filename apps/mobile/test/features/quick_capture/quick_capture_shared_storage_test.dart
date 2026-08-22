import 'dart:io';

import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_shared_storage.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_widget_bridge.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBridge implements QuickCaptureWidgetBridge {
  _RecordingBridge(this._captures);

  final List<Map<String, dynamic>> _captures;
  final List<String> acknowledged = [];

  @override
  Future<void> acknowledgeCaptureIds(List<String> captureIds) async {
    acknowledged.addAll(captureIds);
  }

  @override
  Future<String> consumePendingLaunchRoute() async => '/quick-capture';

  @override
  Future<void> clearWidgetSnapshot() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<Map<String, dynamic>>> readPendingCaptures() async =>
      List<Map<String, dynamic>>.from(_captures);

  @override
  Future<void> updateWidgetSnapshot(Map<String, String> payload) async {}
}

void main() {
  late Directory tempDir;
  late MobilePrefsStore prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quick_capture_shared_');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('prefers native bridge payloads over prefs fallback', () async {
    await prefs.writeString(
      QuickCaptureSharedStorage.sharedQueueKey,
      '[{"captureId":"prefs-only","kind":"text","text":"ignored"}]',
    );
    final bridge = _RecordingBridge([
      {
        'captureId': 'native-1',
        'kind': 'text',
        'text': 'From widget',
        'durationSeconds': 0,
        'source': 'widget',
        'createdAt': DateTime.utc(2026).toIso8601String(),
      },
    ]);
    final storage = QuickCaptureSharedStorage(bridge: bridge, prefs: prefs);

    final pending = await storage.readPendingCaptures();
    expect(pending, hasLength(1));
    expect(pending.single.captureId, 'native-1');
  });

  test('acknowledge removes prefs fallback entries', () async {
    const bridge = NoOpQuickCaptureWidgetBridge();
    final storage = QuickCaptureSharedStorage(bridge: bridge, prefs: prefs);
    await storage.enqueueLocalFallback(
      QuickCaptureOutboxPayload(
        captureId: 'local-1',
        kind: QuickCaptureKind.text,
        text: 'Shortcut note',
      ),
    );

    await storage.acknowledgeCaptureIds(['local-1']);
    expect(await storage.readPendingCaptures(), isEmpty);
  });
}
