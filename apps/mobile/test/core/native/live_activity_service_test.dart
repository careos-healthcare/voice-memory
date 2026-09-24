import 'package:archiveme_mobile/core/native/live_activity_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(LiveActivityService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decibels map into the 0...1 waveform range', () {
    expect(LiveActivityService.normalizeDecibel(-55), 0);
    expect(LiveActivityService.normalizeDecibel(-8), 1);
    expect(LiveActivityService.normalizeDecibel(-31.5), closeTo(0.5, 0.0001));
    expect(LiveActivityService.normalizeDecibel(-80), 0);
    expect(LiveActivityService.normalizeDecibel(3), 1);
    expect(LiveActivityService.normalizeDecibel(double.nan), 0);
  });

  test(
    'recording start, throttled waveform, and stop use the channel',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });

      var now = DateTime(2026, 9, 21, 12);
      final service = LiveActivityService(
        channel: channel,
        clock: () => now,
        enabled: true,
      );

      await service.start(recordingId: 'moment-1');
      expect(service.isSessionOpen, isTrue);
      expect(calls.single.method, LiveActivityService.startMethod);
      expect(calls.single.arguments, {
        'recordingId': 'moment-1',
        'startDate': now.millisecondsSinceEpoch,
      });

      service.pushDecibel(-31.5);
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(2));
      final firstUpdate = calls[1].arguments! as Map<Object?, Object?>;
      expect(firstUpdate['isPaused'], isFalse);
      final firstBars = firstUpdate['decibels']! as List<Object?>;
      expect(firstBars, hasLength(8));
      expect(firstBars.last, closeTo(0.5, 0.0001));

      now = now.add(const Duration(milliseconds: 200));
      service.pushDecibel(-8);
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(2));
      expect(service.levels.last, 1);

      now = now.add(const Duration(milliseconds: 500));
      service.pushDecibel(-55);
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(3));
      final secondUpdate = calls[2].arguments! as Map<Object?, Object?>;
      final secondBars = secondUpdate['decibels']! as List<Object?>;
      expect(secondBars, hasLength(LiveActivityService.barCount));
      expect(secondBars.last, 0);

      await service.setPaused(isPaused: true);
      expect(calls.last.method, LiveActivityService.updateMethod);
      expect(
        (calls.last.arguments! as Map<Object?, Object?>)['isPaused'],
        isTrue,
      );
      final sentWhilePaused = calls.length;
      service.pushDecibel(-8);
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(sentWhilePaused));

      await service.end();
      expect(service.isSessionOpen, isFalse);
      expect(calls.last.method, LiveActivityService.endMethod);

      await service.end();
      expect(
        calls.where((call) => call.method == LiveActivityService.endMethod),
        hasLength(1),
      );
    },
  );

  test('island pause and stop call the recording session', () async {
    var pauses = 0;
    var stops = 0;
    final service = LiveActivityService(channel: channel, enabled: true)
      ..bindControls(
        onTogglePause: () async {
          pauses += 1;
        },
        onStop: () async {
          stops += 1;
        },
      );

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    await messenger.handlePlatformMessage(
      LiveActivityService.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall(LiveActivityService.togglePauseMethod),
      ),
      (_) {},
    );
    await messenger.handlePlatformMessage(
      LiveActivityService.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall(LiveActivityService.stopMethod),
      ),
      (_) {},
    );

    expect(pauses, 1);
    expect(stops, 1);
  });
}
