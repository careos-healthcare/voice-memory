import 'package:archiveme_mobile/features/ambient_capture/ambient_capture_router.dart';
import 'package:archiveme_mobile/features/ambient_capture/home_screen_shortcuts.dart';
import 'package:archiveme_mobile/features/ambient_capture/record_widget_launch.dart';
import 'package:archiveme_mobile/features/ambient_capture/shortcut_record_launch.dart';
import 'package:archiveme_mobile/features/capture/zero_state_recorder.dart';
import 'package:flutter/services.dart';
import 'package:archiveme_mobile/features/capture/capture_module_config.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    AmbientCaptureRouter.pendingLocation = null;
  });

  test('New Voice Entry opens the recording capture route', () {
    expect(
      HomeScreenShortcuts.locationFor(HomeScreenShortcuts.newVoiceEntry),
      CaptureDeepLinkUris.recordLaunchRoute,
    );
    expect(
      HomeScreenShortcuts.items.first.localizedTitle,
      'New Voice Entry',
    );
  });

  test('Quick Text opens typed capture', () {
    expect(
      HomeScreenShortcuts.locationFor(HomeScreenShortcuts.quickText),
      V1RouteRegistry.quickCapturePath,
    );
    expect(
      HomeScreenShortcuts.items.last.localizedTitle,
      'Quick Text',
    );
  });

  test('an unknown shortcut does not open a route', () {
    expect(HomeScreenShortcuts.locationFor('something_else'), isNull);
  });

  test('the record widget URI is the recording launch', () {
    expect(
      RecordWidgetLaunch.isRecordLaunch(
        Uri.parse('archiveme://record?homeWidget'),
      ),
      isTrue,
    );
    expect(
      RecordWidgetLaunch.isRecordLaunch(
        Uri.parse('archiveme://quick-capture?text=note'),
      ),
      isFalse,
    );
  });

  test('a shortcut launch buffers audio before later startup work', () async {
    final calls = <String>[];
    const channel = MethodChannel(ZeroStateRecorder.channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == ShortcutRecordLaunch.consumeMethod) return true;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      ShortcutRecordLaunch.earlyBufferPath = null;
    });

    var providersStarted = false;
    final buffered = await ShortcutRecordLaunch.beginBeforeUi(channel: channel);
    expect(buffered, isTrue);
    expect(calls, [
      ShortcutRecordLaunch.consumeMethod,
      ShortcutRecordLaunch.beginMethod,
    ]);
    expect(
      AmbientCaptureRouter.pendingLocation,
      CaptureDeepLinkUris.recordLaunchRoute,
    );
    providersStarted = true;
    expect(providersStarted, isTrue);
    expect(calls, isNot(contains('completeArchiveMeStartup')));
  });

  test('a normal launch does not open the microphone buffer', () async {
    var began = false;
    const channel = MethodChannel('com.archiveme/zero_state_recorder_idle');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == ShortcutRecordLaunch.beginMethod) began = true;
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final buffered = await ShortcutRecordLaunch.beginBeforeUi(channel: channel);
    expect(buffered, isFalse);
    expect(began, isFalse);
  });

  test('a launch before the navigator stays pending', () {
    AmbientCaptureRouter.go(CaptureDeepLinkUris.recordLaunchRoute);
    expect(
      AmbientCaptureRouter.pendingLocation,
      CaptureDeepLinkUris.recordLaunchRoute,
    );
    AmbientCaptureRouter.flush();
    expect(
      AmbientCaptureRouter.pendingLocation,
      CaptureDeepLinkUris.recordLaunchRoute,
    );
  });
}
