import 'dart:async';

Future<void> testExecutable(Future<void> Function() testMain) async {
  await testMain();
}
