import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/archive_review/archive_range_review_engine.dart';
import 'package:voicememory_mobile/features/moments/key_moment_model.dart';
import 'package:archiveme_research/screens/archive_range_review_screen.dart';

KeyMoment _moment(String id, DateTime date, {String? resultHint}) => KeyMoment(
  id: id,
  date: date,
  title: 'Moment $id',
  originalText: 'text',
  shortSummary: 'Summary for $id',
  patternTitle: 'Work pressure',
  resultHint: resultHint ?? 'same',
);

List<KeyMoment> _sixMoments() => List.generate(
  6,
  (i) => _moment('m$i', DateTime(2026, 6, 6).subtract(Duration(days: i))),
);

void main() {
  testWidgets('screen renders key moments', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveRangeReviewScreen(
          now: DateTime(2026, 6, 6),
          firstLoopClosed: true,
          skipPersistence: true,
          entitlementReader: FakeArchiveEntitlementReader(pro: true),
          momentsLoader: () async => _sixMoments(),
          onUseCheck: (_) async {},
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Archive review'), findsWidgets);
    expect(find.text('Key moments from this period'), findsOneWidget);
    expect(find.text('Summary for m0'), findsOneWidget);
  });

  testWidgets('Use this check fires', (tester) async {
    var used = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveRangeReviewScreen(
          now: DateTime(2026, 6, 6),
          firstLoopClosed: true,
          skipPersistence: true,
          entitlementReader: FakeArchiveEntitlementReader(pro: true),
          momentsLoader: () async => _sixMoments(),
          onUseCheck: (_) async {
            used = true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this check').first);
    await tester.pumpAndSettle();
    expect(used, isTrue);
    expect(find.text('Tomorrow\u2019s check is set.'), findsOneWidget);
  });

  test('build produces enough data for six moments', () {
    expect(
      buildArchiveRangeReview(
        moments: _sixMoments(),
        now: DateTime(2026, 6, 6),
      ).hasEnoughData,
      isTrue,
    );
  });
}
