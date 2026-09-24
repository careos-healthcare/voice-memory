import 'package:archiveme_mobile/features/capture/zero_state_recorder.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a direct record keeps the quote and starts after the native prime',
    () async {
      final order = <String>[];
      const channel = MethodChannel(ZeroStateRecorder.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, ZeroStateRecorder.primeMethod);
            order.add('prime');
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final request = DirectRecordRequest.fromUri(
        Uri.parse(
          'archiveme://record?source=reflex&quote=The%20rent%20is%20due&autostart=1',
        ),
      );
      final recorder = ZeroStateRecorder(
        channel: channel,
        request: request,
        startCapture: () async {
          order.add('start');
        },
      );
      addTearDown(recorder.disarm);

      expect(request.line, 'The rent is due');
      expect(recorder.mode, ZeroStateRecorderMode.quoteFirst);
      await recorder.arm();
      expect(order, ['prime', 'start']);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(Duration.zero);
      expect(order, ['prime', 'start', 'prime']);
    },
  );

  test(
    'a home direct record without autostart only primes the microphone',
    () async {
      var primes = 0;
      var starts = 0;
      const channel = MethodChannel('com.archiveme/zero_state_recorder_home');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            primes += 1;
            final args = call.arguments as Map<Object?, Object?>;
            expect(args['alreadyRecording'], isFalse);
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final recorder = ZeroStateRecorder(
        channel: channel,
        request: const DirectRecordRequest(source: 'home', autoStart: false),
        startCapture: () async {
          starts += 1;
        },
      );
      addTearDown(recorder.disarm);

      expect(recorder.mode, ZeroStateRecorderMode.oneLineMic);
      await recorder.arm();
      expect(primes, 1);
      expect(starts, 0);
    },
  );
}
