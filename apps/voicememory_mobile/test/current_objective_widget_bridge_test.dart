import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/objective/current_objective_widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NoOp bridge is unavailable and safe', () async {
    const bridge = NoOpCurrentObjectiveWidgetBridge();
    expect(await bridge.isAvailable(), isFalse);
    await bridge.update({'title': 'Today\u2019s check'});
    await bridge.clear();
    expect(await bridge.consumePendingWidgetRoute(), '');
  });

  test('MethodChannel bridge handles missing plugin safely', () async {
    final bridge = MethodChannelCurrentObjectiveWidgetBridge();
    expect(await bridge.isAvailable(), isFalse);
    await bridge.update({'title': 'Today\u2019s check'});
    await bridge.clear();
    expect(await bridge.consumePendingWidgetRoute(), '');
  });

  test('MethodChannel bridge forwards update when handler exists', () async {
    Map<dynamic, dynamic>? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('archive_me/current_objective_widget'),
      (call) async {
        if (call.method == 'isCurrentObjectiveWidgetAvailable') {
          return true;
        }
        if (call.method == 'updateCurrentObjectiveWidget') {
          captured = call.arguments as Map<dynamic, dynamic>?;
          return null;
        }
        return null;
      },
    );

    final bridge = MethodChannelCurrentObjectiveWidgetBridge();
    expect(await bridge.isAvailable(), isTrue);
    await bridge.update({'title': 'Today\u2019s check', 'route': '/record'});
    expect(captured?['title'], 'Today\u2019s check');
    expect(captured?['route'], '/record');
    for (final value in captured!.values) {
      expect(value, isA<String>());
    }

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('archive_me/current_objective_widget'),
      null,
    );
  });

  test('MethodChannel bridge clear invokes native clear', () async {
    var clearCalled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('archive_me/current_objective_widget'),
      (call) async {
        if (call.method == 'clearCurrentObjectiveWidget') {
          clearCalled = true;
          return null;
        }
        if (call.method == 'isCurrentObjectiveWidgetAvailable') {
          return true;
        }
        return null;
      },
    );

    final bridge = MethodChannelCurrentObjectiveWidgetBridge();
    await bridge.clear();
    expect(clearCalled, isTrue);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('archive_me/current_objective_widget'),
      null,
    );
  });

  test('MethodChannel bridge returns pending route from handler', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('archive_me/current_objective_widget'),
      (call) async {
        if (call.method == 'consumePendingWidgetRoute') {
          return '/record';
        }
        return null;
      },
    );

    final bridge = MethodChannelCurrentObjectiveWidgetBridge();
    expect(await bridge.consumePendingWidgetRoute(), '/record');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('archive_me/current_objective_widget'),
      null,
    );
  });
}
