import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android graph widgets declare home and keyguard categories', () {
    for (final name in [
      'quick_capture_widget_info.xml',
      'micro_habit_widget_info.xml',
      'semantic_cluster_widget_info.xml',
    ]) {
      final source = File(
        'android/app/src/main/res/xml/$name',
      ).readAsStringSync();
      expect(source, contains('android:widgetCategory="home_screen|keyguard"'));
    }
  });

  test(
    'Android encrypted widget state retains lock-screen privacy setting',
    () {
      final source = File(
        'android/app/src/main/kotlin/com/voicememory/mobile/widget/'
        'AndroidWidgetStorage.kt',
      ).readAsStringSync();
      expect(source, contains('"lockScreenEnabled"'));
      expect(source, contains('SecureNativeStorage.writeEncryptedAtomic'));
    },
  );

  test('legacy iOS objective payload cannot overwrite graph widget state', () {
    final objective = File(
      'ios/Runner/ObjectiveWidgetStorage.swift',
    ).readAsStringSync();
    final active = File(
      'ios/ArchiveMeWidgets/ArchiveMeWidgets.swift',
    ).readAsStringSync();
    expect(objective, contains('category = "objective-widget"'));
    expect(active, contains('category: "widget"'));
    expect(active, contains('identifier: "current"'));
  });
}
