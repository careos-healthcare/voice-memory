import 'package:flutter_test/flutter_test.dart';

import 'helpers/mock_audioplayers.dart';
import 'support/release_suite_static_state_reset.dart';

/// Installs platform boundaries shared by every Flutter test isolate.
Future<void> testExecutable(Future<void> Function() testMain) async {
  installMockAudioplayers();
  setUp(() async {
    await ReleaseSuiteStaticStateReset.resetCachedState();
  });
  await testMain();
}
