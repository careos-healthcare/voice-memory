import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/objective/current_objective_model.dart';
import 'package:voicememory_mobile/widgets/objective/current_objective_card.dart';

void main() {
  testWidgets('primary callback fires when CTA is tapped', (tester) async {
    var tapped = false;
    const objective = CurrentObjective(
      type: CurrentObjectiveType.recordFirstMoment,
      title: 'Start with one moment',
      body: 'Record one moment to start finding what repeats.',
      primaryCtaLabel: 'Record one moment',
      route: '/record',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurrentObjectiveCard(
            objective: objective,
            persistSnapshot: false,
            onPrimaryTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Record one moment'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('shows check question when present', (tester) async {
    const objective = CurrentObjective(
      type: CurrentObjectiveType.answerTodayCheck,
      title: 'Today\u2019s check',
      body: 'Answer the check you chose yesterday.',
      checkQuestion: 'What happens right before it shows up?',
      primaryCtaLabel: 'Answer check',
      route: '/record',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurrentObjectiveCard(
            objective: objective,
            persistSnapshot: false,
          ),
        ),
      ),
    );

    expect(find.text(objective.checkQuestion!), findsOneWidget);
  });
}
