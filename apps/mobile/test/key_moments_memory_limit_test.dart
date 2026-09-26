import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_research/screens/key_moments_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

KeyMoment _moment(String id, DateTime date, {String title = 'Moment'}) =>
    KeyMoment(
      id: id,
      date: date,
      title: title,
      originalText: title,
      shortSummary: 'Summary for $title',
    );

List<KeyMoment> _manyMoments(int count) => List.generate(
  count,
  (i) => _moment(
    'm$i',
    DateTime.now().subtract(Duration(minutes: i)),
    title: 'Moment $i',
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<KeyMoment> moments,
  bool pro = false,
  bool firstLoopClosed = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: KeyMomentsScreen(
        loader: () async => moments,
        entitlementReader: FakeArchiveEntitlementReader(pro: pro),
        firstLoopClosed: firstLoopClosed,
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
}

void main() {
  testWidgets('every saved moment stays visible', (tester) async {
    await _pump(tester, moments: _manyMoments(8));

    expect(find.text('Your pattern memory is growing'), findsNothing);
    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 7'), findsOneWidget);
  });

  testWidgets('Pro user sees all moments without limit card', (tester) async {
    await _pump(tester, moments: _manyMoments(8), pro: true);

    expect(find.text('Your pattern memory is growing'), findsNothing);
    expect(find.text(ConsumerUiCopy.freeKeepsSevenKeyMoments), findsNothing);
    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 7'), findsOneWidget);
  });

  testWidgets('search stays available no matter how many moments exist', (
    tester,
  ) async {
    await _pump(tester, moments: _manyMoments(8));

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TextField), findsOneWidget);
  });
}