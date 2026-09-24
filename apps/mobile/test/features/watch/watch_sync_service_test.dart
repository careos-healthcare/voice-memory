import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:archiveme_mobile/features/watch/watch_sync_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WatchSyncService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('pending watch recording is ready for transcription', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == WatchSyncService.consumePendingMethod) {
            return [
              {
                'path': '/group/watch_recordings/watch_capture_1.m4a',
                'capturedAt': '2026-09-21T12:00:00.000Z',
                'durationSeconds': 4,
              },
            ];
          }
          return null;
        });

    final ready = <WatchAudioCapture>[];
    final service = WatchSyncService(channel: channel);
    await service.bind(onReady: ready.add);

    expect(ready, hasLength(1));
    expect(
      ready.single.path,
      '/group/watch_recordings/watch_capture_1.m4a',
    );
    expect(ready.single.durationSeconds, 4);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          WatchSyncService.channelName,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall(WatchSyncService.readyMethod, {
              'path': '/group/watch_recordings/watch_capture_2.m4a',
              'durationSeconds': 2,
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(ready, hasLength(2));
    expect(ready.last.durationSeconds, 2);
  });
}
