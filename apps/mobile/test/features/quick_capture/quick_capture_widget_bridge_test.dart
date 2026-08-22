import 'package:archiveme_mobile/features/quick_capture/quick_capture_widget_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NoOp bridge is unavailable and safe', () async {
    const bridge = NoOpQuickCaptureWidgetBridge();
    expect(await bridge.isAvailable(), isFalse);
    expect(await bridge.readPendingCaptures(), isEmpty);
    await bridge.updateWidgetSnapshot({'title': 'Quick capture'});
    await bridge.clearWidgetSnapshot();
    expect(await bridge.consumePendingLaunchRoute(), '');
  });

  test('MethodChannel bridge forwards read and acknowledge', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('archive_me/quick_capture_widget'),
          (call) async {
            switch (call.method) {
              case 'isQuickCaptureWidgetAvailable':
                return true;
              case 'readPendingQuickCaptures':
                return [
                  {
                    'captureId': 'cap-1',
                    'kind': 'text',
                    'text': 'Hello widget',
                  },
                ];
              case 'acknowledgeQuickCaptures':
                final args = call.arguments as Map<dynamic, dynamic>;
                expect(args['captureIds'], ['cap-1']);
                return null;
              default:
                return null;
            }
          },
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('archive_me/quick_capture_widget'),
            null,
          );
    });

    final bridge = MethodChannelQuickCaptureWidgetBridge();
    expect(await bridge.isAvailable(), isTrue);
    final pending = await bridge.readPendingCaptures();
    expect(pending.single['captureId'], 'cap-1');
    await bridge.acknowledgeCaptureIds(['cap-1']);
  });
}
