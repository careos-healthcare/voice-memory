import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/signal_journey_screen.dart';
import 'package:voicememory_mobile/widgets/signal/signal_journey_card.dart';
import 'package:voicememory_mobile/widgets/signal/signal_journey_completion_card.dart';

SignalJourney _journey({
  SignalJourneyStatus status = SignalJourneyStatus.gettingClearer,
  int supporting = 2,
  bool completionAcknowledged = false,
}) {
  return SignalJourney(
    id: 'j1',
    signalId: 'sig1',
    signalTitle: 'Saying yes before checking capacity',
    status: status,
    evidenceCount: supporting,
    targetEvidenceCount: 3,
    acceptedReadCount: supporting,
    rejectedReadCount: 0,
    contradictionCount: 0,
    startedAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 3),
    nextPrompt: 'When did you last say yes while already stretched?',
    supportingMomentIds: List.generate(supporting, (i) => 'e$i'),
    wouldConfirm: 'Another moment where you say yes while already full.',
    wouldChallenge: 'Moments where you pause before answering.',
    evidenceSummary: 'You mentioned pressure and saying yes.',
    completionAcknowledged: completionAcknowledged,
  );
}

void main() {
  testWidgets('record tab journey card renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignalJourneyCard(journey: _journey(), compact: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.signalJourneyTitle), findsOneWidget);
    expect(
      find.textContaining('Saying yes before checking capacity'),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.signalJourneyRecordEvidence),
      findsOneWidget,
    );
  });

  testWidgets('journey detail screen renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SignalJourneyScreen(initialJourney: _journey())),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.signalJourneyDetailTitle), findsOneWidget);
    expect(
      find.textContaining('Saying yes before checking capacity'),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.signalJourneyWouldConfirm), findsOneWidget);
  });

  testWidgets('completion card appears at 3 evidence items', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignalJourneyCompletionCard(
            journey: _journey(
              status: SignalJourneyStatus.confirmedPattern,
              supporting: 3,
            ),
            onKeepWatching: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(ConsumerUiCopy.signalJourneyCompletionTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(ConsumerUiCopy.signalJourneyKeepWatching));
    expect(dismissed, isTrue);
  });

  testWidgets('empty journey detail state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignalJourneyScreen(initialJourney: null)),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.signalJourneyEmptyTitle), findsOneWidget);
  });

  testWidgets('record evidence CTA routes to record', (tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) =>
                  SignalJourneyCard(journey: _journey(), compact: true),
            ),
            GoRoute(
              path: '/record',
              builder: (_, __) => const Scaffold(body: Text('Record tab')),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(ConsumerUiCopy.signalJourneyRecordEvidence));
    await tester.pumpAndSettle();

    expect(find.text('Record tab'), findsOneWidget);
  });
}
