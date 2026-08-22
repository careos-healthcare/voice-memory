import 'package:archiveme_mobile/core/config/watch_companion_feature_flags.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:archiveme_mobile/features/watch_companion/watch_connectivity_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WatchConnectivityService.channelName);

  tearDown(() async {
    WatchCompanionFeatureFlags.debugOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses archive_me/watch_session channel name', () {
    expect(WatchConnectivityService.channelName, 'archive_me/watch_session');
  });

  test('connect is a no-op when feature flag is off', () async {
    WatchCompanionFeatureFlags.debugOverride = false;
    var handlerCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          handlerCalls++;
          return null;
        });

    final service = WatchConnectivityService();
    await service.connect();

    expect(handlerCalls, 0);
    service.dispose();
  });

  test('connect registers handler and drains pending captures when enabled', () async {
    WatchCompanionFeatureFlags.debugOverride = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'consumePendingWatchAudio':
              return [
                {
                  'path': '/tmp/watch_inbox/watch_capture_1.m4a',
                  'durationSeconds': 9,
                  'capturedAt': '2026-01-15T12:00:00.000Z',
                },
              ];
            case 'isWatchSessionSupported':
              return true;
            default:
              return null;
          }
        });

    final service = WatchConnectivityService()..forceConnectForTests = true;
    final received = <WatchAudioCapture>[];
    await service.connect(onCapture: received.add);

    expect(received, hasLength(1));
    expect(received.single.path, '/tmp/watch_inbox/watch_capture_1.m4a');
    expect(received.single.durationSeconds, 9);
    expect(await service.isSupported(), isTrue);

    service.dispose();
  });
}