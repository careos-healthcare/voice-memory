import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/signal/return_day_journey_card.dart';

SignalJourney _journey() {
  return SignalJourney(
    id: 'j1',
    signalId: 'sig1',
    signalTitle: 'Saying yes before checking capacity',
    status: SignalJourneyStatus.gettingClearer,
    evidenceCount: 1,
    targetEvidenceCount: 3,
    acceptedReadCount: 1,
    rejectedReadCount: 0,
    contradictionCount: 0,
    startedAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
    nextPrompt: 'When did you last say yes while already stretched?',
    supportingMomentIds: const ['e1'],
  );
}

void main() {
  testWidgets('return-day card shows continue journey copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReturnDayJourneyCard(journey: _journey(), recordedToday: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.returnDayJourneyTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.returnDayJourneyRecordCta), findsOneWidget);
    expect(find.text(ConsumerUiCopy.returnDayJourneyViewCta), findsOneWidget);
    expect(
      find.textContaining('Saying yes before checking capacity'),
      findsOneWidget,
    );
  });

  testWidgets('return-day recorded-today state shows saved copy', (
    tester,
  ) async {
    var viewed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReturnDayJourneyCard(
            journey: _journey(),
            recordedToday: true,
            onViewChanged: () => viewed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(ConsumerUiCopy.returnDayEvidenceSavedTitle),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.returnDayEvidenceSavedCta), findsOneWidget);
    expect(find.text(ConsumerUiCopy.returnDayJourneyRecordCta), findsNothing);

    await tester.tap(find.text(ConsumerUiCopy.returnDayEvidenceSavedCta));
    await tester.pumpAndSettle();
    expect(viewed, isTrue);
  });

  testWidgets('view journey routes via navigation helper', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              ReturnDayJourneyCard(journey: _journey(), recordedToday: false),
        ),
        GoRoute(
          path: '/signal-journey',
          builder: (context, state) =>
              const Scaffold(body: Text('Journey detail')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ConsumerUiCopy.returnDayJourneyViewCta));
    await tester.pumpAndSettle();

    expect(find.text('Journey detail'), findsOneWidget);
  });
}
