import 'package:flutter_test/flutter_test.dart';

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 50),
  String reason = 'condition',
}) async {
  final attempts = (timeout.inMicroseconds / step.inMicroseconds).ceil();
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(step);
    if (condition()) return;
  }
  fail('Timed out after $timeout waiting for $reason');
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) => pumpUntil(
  tester,
  () => finder.evaluate().isNotEmpty,
  timeout: timeout,
  reason: '$finder to appear',
);

Future<void> pumpUntilAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) => pumpUntil(
  tester,
  () => finder.evaluate().isEmpty,
  timeout: timeout,
  reason: '$finder to disappear',
);
