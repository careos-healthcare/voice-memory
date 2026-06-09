import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/signal_review_screen.dart';
import 'package:voicememory_mobile/widgets/signal/signal_review_card.dart';

SignalReview _review({
  SignalReviewStatus status = SignalReviewStatus.ready,
}) {
  return SignalReview(
    id: 'sr1',
    journeyId: 'j1',
    signalTitle: 'Saying yes before checking capacity',
    reviewStatus: status,
    evidenceCount: 3,
    whatRepeated:
        'So far, “Saying yes before checking capacity” seems to show up across 3 moments.',
    whatChanged: 'No strong contradictions yet — the read may still hold.',
    evidenceLines: const [
      'I said yes again even though I was already stretched thin.',
      'Another yes while already full from earlier commitments.',
    ],
    possibleContradictions:
        'Moments where you pause before answering.',
    whatToWatchNext: 'When did you last say yes while already stretched?',
    nextEvidencePrompt: 'When did you last say yes while already stretched?',
    createdAt: DateTime(2026, 6, 3),
    updatedAt: DateTime(2026, 6, 3),
  );
}

void main() {
  Future<void> _largeSurface(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(child);
    await tester.pump();
  }

  testWidgets('review card renders', (tester) async {
    var confirmed = false;
    await _largeSurface(
      tester,
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SignalReviewCard(
              review: _review(),
              onConfirm: () => confirmed = true,
              onCorrect: () {},
              onKeepWatching: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text(ConsumerUiCopy.signalReviewCardTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.signalReviewWhatRepeated), findsOneWidget);
    expect(find.text(ConsumerUiCopy.signalReviewFeelsRight), findsOneWidget);

    await tester.ensureVisible(find.text(ConsumerUiCopy.signalReviewFeelsRight));
    await tester.tap(find.text(ConsumerUiCopy.signalReviewFeelsRight));
    expect(confirmed, isTrue);
  });

  testWidgets('full review screen renders', (tester) async {
    await _largeSurface(
      tester,
      MaterialApp(home: SignalReviewScreen(initialReview: _review())),
    );

    expect(find.text(ConsumerUiCopy.signalReviewWhatRepeated), findsOneWidget);
    await tester.ensureVisible(find.text(ConsumerUiCopy.signalReviewConfirmPattern));
    expect(find.text(ConsumerUiCopy.signalReviewConfirmPattern), findsOneWidget);
  });

  testWidgets('empty review screen state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignalReviewScreen(initialReview: null)),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.signalReviewEmptyTitle), findsOneWidget);
    expect(find.text(ConsumerUiCopy.signalReviewRecordMoment), findsOneWidget);
  });

  testWidgets('view full review routes', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: SingleChildScrollView(
              child: SignalReviewCard(
                review: _review(),
                onConfirm: () {},
                onCorrect: () {},
                onKeepWatching: () {},
                onViewFull: () => GoRouter.of(context).push('/signal-review'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/signal-review',
          builder: (_, __) => SignalReviewScreen(initialReview: _review()),
        ),
      ],
    );
    await _largeSurface(tester, MaterialApp.router(routerConfig: router));

    await tester.ensureVisible(find.text(ConsumerUiCopy.signalReviewViewFull));
    await tester.tap(find.text(ConsumerUiCopy.signalReviewViewFull));
    await tester.pumpAndSettle();

    expect(find.byType(SignalReviewScreen), findsOneWidget);
    expect(find.text(ConsumerUiCopy.signalReviewConfirmPattern), findsOneWidget);
  });

  testWidgets('weak evidence card shows needs more copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SignalReviewCard(
            review: _review().copyWith(
              needsMoreEvidence: true,
              reviewStatus: SignalReviewStatus.draft,
              whatRepeated: '',
            ),
            onConfirm: () {},
            onCorrect: () {},
            onKeepWatching: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(ConsumerUiCopy.signalReviewNeedsMoreEvidence), findsOneWidget);
  });
}
