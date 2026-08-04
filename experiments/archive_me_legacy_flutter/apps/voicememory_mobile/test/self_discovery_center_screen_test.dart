import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/screens/blind_spots_screen.dart';
import 'package:voicememory_mobile/screens/identity_screen.dart';
import 'package:voicememory_mobile/screens/life_chapters_screen.dart';
import 'package:voicememory_mobile/screens/self_discovery_center_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_self_discovery_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('center groups the three reusable discovery views into tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SelfDiscoveryCenterScreen()),
    );

    expect(find.text('Self-discovery'), findsOneWidget);
    expect(find.text('Blind spots'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Life chapters'), findsOneWidget);
    expect(find.byType(BlindSpotsView), findsOneWidget);
    expect(const IdentityView(), isA<StatefulWidget>());
    expect(const LifeChaptersView(), isA<StatefulWidget>());
  });

  test('deep-link tab names resolve to stable indices', () {
    expect(SelfDiscoveryCenterScreen.tabIndexFor('blind-spots'), 0);
    expect(SelfDiscoveryCenterScreen.tabIndexFor('identity'), 1);
    expect(SelfDiscoveryCenterScreen.tabIndexFor('life-chapters'), 2);
    expect(SelfDiscoveryCenterScreen.tabIndexFor('unknown'), 0);
  });
}
