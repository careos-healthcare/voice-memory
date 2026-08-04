import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/screens/key_moments_screen.dart';

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
  testWidgets('free archive shows all moments without a limit card', (
    tester,
  ) async {
    await _pump(tester, moments: _manyMoments(8));

    expect(find.text('Your pattern memory is growing'), findsNothing);
    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 7'), findsOneWidget);
  });

  testWidgets('Pro user sees all moments without limit card', (tester) async {
    await _pump(tester, moments: _manyMoments(8), pro: true);

    expect(find.text('Your pattern memory is growing'), findsNothing);
    expect(find.textContaining('first 7 key moments'), findsNothing);
    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 7'), findsOneWidget);
  });

  testWidgets('free user sees moments beyond the retired seven-item boundary', (
    tester,
  ) async {
    await _pump(tester, moments: _manyMoments(8));

    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 7'), findsOneWidget);
  });

  testWidgets('search is not gated at 7 moments or fewer', (tester) async {
    await _pump(tester, moments: _manyMoments(7));

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TextField), findsOneWidget);
  });
}
