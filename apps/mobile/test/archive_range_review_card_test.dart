import 'package:archiveme_mobile/features/archive_review/archive_range_review_model.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_range_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveRangeReview _sampleReview() => ArchiveRangeReview(
  id: 'r1',
  preset: ArchiveReviewRangePreset.thisWeek,
  startDate: DateTime(2026, 6),
  endDate: DateTime(2026, 6, 6),
  title: 'This week',
  type: ArchiveRangeReviewType.lighter,
  momentCount: 6,
  patternCount: 1,
  lighterLine: 'It felt lighter in 3 moments.',
  repeatedLine: 'This pattern showed up 4 times.',
  nextCheck: 'What happens right before it shows up?',
  keyMomentIds: const ['m1', 'm2'],
);

void main() {
  testWidgets('card renders review and next check', (tester) async {
    String? usedCheck;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveRangeReviewCard(
            review: _sampleReview(),
            onOpenReview: () {},
            onUseCheck: (q) => usedCheck = q,
          ),
        ),
      ),
    );

    expect(find.text('Archive review'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('It felt lighter in 3 moments.'), findsOneWidget);
    expect(find.text('What happens right before it shows up?'), findsOneWidget);

    await tester.tap(find.text('Use this check'));
    await tester.pumpAndSettle();
    expect(usedCheck, 'What happens right before it shows up?');
  });

  testWidgets('shows not enough message when below threshold', (tester) async {
    final review = _sampleReview().copyWith(
      momentCount: 2,
      type: ArchiveRangeReviewType.notEnoughYet,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ArchiveRangeReviewCard(review: review)),
      ),
    );

    expect(
      find.text('Record a few more moments in this period.'),
      findsOneWidget,
    );
  });
}