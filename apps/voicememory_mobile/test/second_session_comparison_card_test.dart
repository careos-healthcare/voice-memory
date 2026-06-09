import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/retention/second_session_signal_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/record/second_session_comparison_card.dart';

void main() {
  testWidgets('CTAs render on comparison card', (tester) async {
    const comparison = SecondSessionComparison(
      hasEnoughData: true,
      title: ConsumerUiCopy.secondSessionPossibleRepeatTitle,
      body: ConsumerUiCopy.secondSessionSoundsClose,
      whatRepeated: 'Both moments may touch on pressure.',
      whatChanged: 'The latest moment may be more about rest.',
      whatToTestNext: 'Notice whether pressure shows up again.',
      previousSignalLabel: 'Carrying responsibility',
      latestSignalLabel: 'Wanting rest',
      possibleRepeat: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecondSessionComparisonCard(
            comparison: comparison,
            onGoDeeper: () {},
            onRecordNextEvidence: () {},
            onNotTheSame: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.postSaveInsightGoDeeper), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.secondSessionNotTheSame), findsOneWidget);
    expect(find.text(ConsumerUiCopy.secondSessionWhatRepeated), findsOneWidget);
  });

  testWidgets('insufficient data shows record CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecondSessionComparisonCard(
            comparison: SecondSessionComparison.insufficient(),
            onGoDeeper: () {},
            onRecordNextEvidence: () {},
            onNotTheSame: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(ConsumerUiCopy.secondSessionNeedMoreMoments),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.postSaveRecordAnother), findsOneWidget);
  });
}
