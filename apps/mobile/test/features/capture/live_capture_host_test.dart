import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const hostPath = 'lib/features/capture/screens/live_capture_host.dart';
  const routerPath = 'lib/router/app_router.dart';

  test('live host stays thin and avoids retired adapters', () {
    final source = File(hostPath).readAsStringSync();
    expect(source, contains('class LiveCaptureHost'));
    expect(
      source,
      contains('features/capture_flow/ui/capture_screen_host.dart'),
    );
    expect(source, isNot(contains('capture_flow_controller')));
    expect(source, isNot(contains('capture_flow/adapters')));
    expect(source, isNot(contains('capture_flow_panels')));
    expect(source, isNot(contains('features/capture_flow/ui/capture_screen.dart')));
  });

  test('production record and quick-capture routes use LiveCaptureHost', () {
    final source = File(routerPath).readAsStringSync();
    expect(source, contains('features/capture/screens/live_capture_host.dart'));
    expect(source, contains('LiveCaptureHost('));
    expect(source, contains('typed: true'));
    expect(source, isNot(contains('screens/record_screen.dart')));
    expect(source, isNot(contains('CaptureScreenHost(')));
  });

  test('record_screen barrel is gone', () {
    expect(File('lib/screens/record_screen.dart').existsSync(), isFalse);
  });
}
