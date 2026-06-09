import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pattern_map/pattern_map_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/pattern_map_screen.dart';

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

void main() {
  testWidgets('shows the map sections and title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PatternMapScreen(
          loader: () async => _map(),
          onUseCheck: (_) async {},
          firstLoopClosed: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pattern map'), findsOneWidget);
    expect(
      find.text('Taking responsibility before asking for help'),
      findsOneWidget,
    );
    expect(find.text('Seen'), findsOneWidget);
    expect(find.text('Next check'), findsOneWidget);
  });

  testWidgets('empty state appears when there is no map', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PatternMapScreen(
          loader: () async => null,
          onUseCheck: (_) async {},
          firstLoopClosed: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Record a few moments'),
      findsOneWidget,
    );
  });

  testWidgets('Use this check fires and confirms', (tester) async {
    String? used;
    await tester.pumpWidget(
      MaterialApp(
        home: PatternMapScreen(
          loader: () async => _map(),
          onUseCheck: (q) async => used = q,
          firstLoopClosed: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Use this check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this check'));
    await tester.pumpAndSettle();

    expect(used, 'What happens right before it shows up?');
    expect(find.textContaining('check is set'), findsOneWidget);
  });

  testWidgets('non-Pro after first loop shows memory limit on full map',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PatternMapScreen(
          loader: () async => _map(),
          onUseCheck: (_) async {},
          entitlementReader: FakeArchiveEntitlementReader(pro: false),
          firstLoopClosed: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.patternMemoryGrowingTitle), findsOneWidget);
    expect(find.text('Keep a private copy'), findsNothing);
  });
}
