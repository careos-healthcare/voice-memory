
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:archiveme_research/screens/pattern_map_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'support/test_storage_sandbox.dart';

PatternMap _map() => PatternMap(
  patternTitle: 'Taking responsibility before asking for help',
  seenCount: 4,
  lastSeenDate: DateTime(2026, 6, 4),
  usuallyStartsBefore: 'before saying yes',
  oftenFeelsLike: 'heavier',
  getsLighterWhen: 'paused before answering',
  getsHeavierWhen: 'took it on alone',
  nextCheck: 'What happens right before it shows up?',
  confidenceLabel: 'Based on 4 check-ins',
);

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 50,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

Future<void> _pumpMap(
  WidgetTester tester, {
  required PatternMapScreen screen,
  Finder? waitFor,
}) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
  await _pumpUntil(tester, waitFor ?? find.byType(PatternMapScreen));
}

PatternMapScreen _screen({
  required Future<PatternMap?> Function() loader,
  Future<void> Function(String nextCheck)? onUseCheck,
  bool firstLoopClosed = false,
  int momentCount = 4,
  bool pro = true,
}) => PatternMapScreen(
  loader: loader,
  onUseCheck: onUseCheck ?? (_) async {},
  entitlementReader: FakeArchiveEntitlementReader(pro: pro),
  firstLoopClosed: firstLoopClosed,
  momentCountLoader: () async => momentCount,
);

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());

  testWidgets('shows the map sections and title', (tester) async {
    await _pumpMap(
      tester,
      screen: _screen(loader: () async => _map()),
      waitFor: find.text('Taking responsibility before asking for help'),
    );

    expect(find.text('Pattern map'), findsOneWidget);
    expect(
      find.text('Taking responsibility before asking for help'),
      findsOneWidget,
    );
    expect(find.text('Seen'), findsOneWidget);
    expect(find.text('Next check'), findsOneWidget);
  });

  testWidgets('empty state appears when there is no map', (tester) async {
    await _pumpMap(
      tester,
      screen: _screen(loader: () async => null, momentCount: 0),
      waitFor: find.textContaining('your pattern map will appear here'),
    );

    expect(
      find.textContaining('your pattern map will appear here'),
      findsOneWidget,
    );
  });

  testWidgets('Use this check fires and confirms', (tester) async {
    String? used;
    await _pumpMap(
      tester,
      screen: _screen(
        loader: () async => _map(),
        onUseCheck: (q) async => used = q,
      ),
      waitFor: find.text('Use this check'),
    );

    await tester.ensureVisible(find.text('Use this check'));
    await tester.pump();
    await tester.tap(find.text('Use this check'));
    await tester.pump();
    await _pumpUntil(tester, find.textContaining('check is set'));

    expect(used, 'What happens right before it shows up?');
    expect(find.textContaining('check is set'), findsOneWidget);
  });

  testWidgets('non-Pro after first loop shows memory limit on full map', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      screen: _screen(
        loader: () async => _map(),
        firstLoopClosed: true,
        pro: false,
      ),
      waitFor: find.text('See more of your pattern map'),
    );

    expect(find.text('See more of your pattern map'), findsOneWidget);
    expect(find.text('Keep a private copy'), findsNothing);
  });
}
