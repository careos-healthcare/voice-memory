import 'package:archiveme_mobile/features/archive_review/archive_range_review_model.dart';
import 'package:archiveme_mobile/widgets/archive/archive_range_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selector changes preset', (tester) async {
    ArchiveReviewRangePreset? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveRangeSelector(
            selected: ArchiveReviewRangePreset.thisWeek,
            onPresetSelected: (p) => selected = p,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Last week'));
    await tester.pumpAndSettle();
    expect(selected, ArchiveReviewRangePreset.lastWeek);
  });

  testWidgets('shows all preset chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArchiveRangeSelector(
            selected: ArchiveReviewRangePreset.thisWeek,
            onPresetSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Last week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Last 30 days'), findsOneWidget);
  });
}