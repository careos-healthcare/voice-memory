import 'dart:io';

import 'package:archiveme_mobile/desktop/desktop_window_host.dart';
import 'package:archiveme_mobile/desktop/desktop_window_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widget tests are not a desktop window host', () {
    expect(DesktopWindowHost.isDesktopHost, isFalse);
    expect(Platform.environment.containsKey('FLUTTER_TEST'), isTrue);
  });

  testWidgets('title bar controls stay out of the mobile test host', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: DesktopWindowHost.chrome()),
    );
    expect(find.byKey(const Key('desktop_window_drag_region')), findsNothing);
    expect(find.byKey(const Key('desktop_window_caption')), findsNothing);
  });

  test('a frame smaller than the minimum is not restored', () async {
    final file = File(
      '${Directory.systemTemp.path}/desktop_window_state_test.json',
    );
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final store = DesktopWindowStateStore(file);
    await store.save(
      const DesktopWindowState(x: 0, y: 0, width: 100, height: 100),
    );
    expect(await store.load(), isNull);
  });
}
