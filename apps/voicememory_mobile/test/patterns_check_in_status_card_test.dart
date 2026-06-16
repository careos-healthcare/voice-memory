import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_check_in_status_card.dart';

TomorrowCheckIn _completed(String optionId) => TomorrowCheckIn(
  id: 't1',
  createdAt: DateTime(2026, 5, 25),
  targetDate: '2026-05-26',
  patternTitle: 'Pattern',
  prompt: 'Tomorrow, check whether this pattern shows up again.',
  question: 'Did this pattern show up again?',
  options: kDefaultTomorrowCheckInOptions,
  selectedOptionId: optionId,
  completedAt: DateTime(2026, 5, 26),
);

void main() {
  testWidgets('compact closed card shows headline and next useful check', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternsCheckInStatusCard.closed(
            completed: _completed('showed_up_again'),
          ),
        ),
      ),
    );

    expect(find.text('It showed up again.'), findsOneWidget);
    expect(find.text('This was a repeat, not a one-off.'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.resultNextCheckTitle), findsOneWidget);
    expect(
      find.text('What happened right before it showed up?'),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.patternsResultUseCheckCta), findsOneWidget);
  });

  testWidgets('Use this check creates the check-in and confirms', (
    tester,
  ) async {
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternsCheckInStatusCard.closed(
            completed: _completed('heavier'),
            onUseCheck: (question) async => created = question,
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.patternsResultUseCheckCta));
    await tester.pump();

    expect(created, 'What made it heavier?');
    expect(
      find.text(ConsumerUiCopy.resultNextCheckConfirmation),
      findsOneWidget,
    );
  });
}
