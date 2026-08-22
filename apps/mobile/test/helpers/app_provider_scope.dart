import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps record/live-audio widget tests with the shared app Riverpod container.
Widget withAppProviderScope(Widget child) {
  return UncontrolledProviderScope(
    container: appProviderContainer,
    child: child,
  );
}

/// Pumps [widget] inside the shared app provider scope.
Future<void> pumpWithAppProviderScope(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(withAppProviderScope(widget));
}