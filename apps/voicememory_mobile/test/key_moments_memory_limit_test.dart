import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/key_moments_screen.dart';

KeyMoment _moment(String id, DateTime date, {String title = 'Moment'}) =>
    KeyMoment(
      id: id,
      date: date,
      title: title,
      originalText: title,
      shortSummary: title,
    );

List<KeyMoment> _manyMoments(int count) => List.generate(
      count,
      (i) => _moment(
        'm$i',
        DateTime.now().subtract(Duration(days: i)),
        title: 'Moment $i',
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<KeyMoment> moments,
  bool pro = false,
  bool firstLoopClosed = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: KeyMomentsScreen(
        loader: () async => moments,
        entitlementReader: FakeArchiveEntitlementReader(pro: pro),
        firstLoopClosed: firstLoopClosed,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('memory-limit card appears when more than 7 moments',
      (tester) async {
    await _pump(tester, moments: _manyMoments(8));

    expect(find.text(ConsumerUiCopy.patternMemoryGrowingTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.freeKeepsSevenKeyMoments), findsOneWidget);
    expect(find.text(ConsumerUiCopy.unlockFullMemoryCta), findsOneWidget);
  });

  testWidgets('Pro user sees all moments without limit card', (tester) async {
    await _pump(tester, moments: _manyMoments(8), pro: true);

    expect(find.text(ConsumerUiCopy.patternMemoryGrowingTitle), findsNothing);
    expect(find.text('Moment 7'), findsOneWidget);
  });

  testWidgets('free user sees only 7 newest moments', (tester) async {
    await _pump(tester, moments: _manyMoments(8));

    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 6'), findsOneWidget);
    expect(find.text('Moment 7'), findsNothing);
  });

  testWidgets('search is not gated at 7 moments or fewer', (tester) async {
    await _pump(tester, moments: _manyMoments(7));

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });
}
