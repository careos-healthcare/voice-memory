
import 'package:flutter_test/flutter_test.dart';

import 'support/release_suite_static_state_reset.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  setUp(() async {
    await ReleaseSuiteStaticStateReset.resetCachedState();
  });
  await testMain();
}
