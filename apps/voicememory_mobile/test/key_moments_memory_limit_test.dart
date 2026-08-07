import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/billing/pro_value_preview_engine.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_research/screens/key_moments_screen.dart';

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
  testWidgets('memory-limit card appears when more than 7 moments', (
    tester,
  ) async {
    await _pump(tester, moments: _manyMoments(8));

    final preview = buildProValuePreview(
      PaywallTriggerContext(
        trigger: PaywallTrigger.fullHistory,
        sourceRoute: '/moments',
        momentCount: 8,
        previewTitle: '',
        previewBody: '',
        ctaLabel: '',
      ),
    );
    expect(find.text(preview.title), findsOneWidget);
    expect(find.text(preview.body), findsOneWidget);
    expect(find.text(ConsumerUiCopy.unlockFullMemoryCta), findsOneWidget);
  });

  testWidgets('Pro user sees all moments without limit card', (tester) async {
    await _pump(tester, moments: _manyMoments(8), pro: true);

    expect(find.text('Your pattern memory is growing'), findsNothing);
    expect(find.text(ConsumerUiCopy.freeKeepsSevenKeyMoments), findsNothing);
    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 7'), findsOneWidget);
  });

  testWidgets('free user sees only 7 newest moments', (tester) async {
    await _pump(tester, moments: _manyMoments(8));

    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 7'), findsNothing);
  });

  testWidgets('search is not gated at 7 moments or fewer', (tester) async {
    await _pump(tester, moments: _manyMoments(7));

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TextField), findsOneWidget);
  });
}
