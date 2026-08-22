import 'package:archiveme_mobile/features/tomorrow_return/return_capture_model.dart';
import 'package:archiveme_mobile/features/tomorrow_return/watch_for_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/todays_watch_for_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WatchForItem _pending() {
  return WatchForItem(
    id: 'wf-today',
    createdAt: DateTime(2026, 5, 25),
    targetDate: DateTime(2026, 5, 26),
    text:
        'Tomorrow, notice if you say yes or carry something before checking what you need.',
    chips: const ['saying yes fast'],
    status: WatchForStatus.pending,
    result: WatchForResult.none,
    shortPrompt: 'Notice if you take responsibility before asking for help.',
    specificPrompt:
        'Tomorrow, notice if you say yes or carry something before checking what you need.',
    situationHint: 'especially when someone expects something from you',
    checkInQuestion: 'Did you ask for help, or carry it alone?',
    promptStrength: 'high',
  );
}

void main() {
  testWidgets(
    'Today watch-for card renders specific prompt and quick answers',
    (tester) async {
      ReturnCaptureSelection? saved;
      final pending = _pending();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TodaysWatchForCard(
              pending: pending,
              persistSelection: (selection) async => saved = selection,
              loadSelection: () async => null,
              trackActivation: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(ConsumerUiCopy.todaysWatchForTitle), findsOneWidget);
      expect(find.text(pending.displaySpecificPrompt), findsOneWidget);
      expect(find.text(pending.situationHint!), findsOneWidget);
      expect(find.text(pending.checkInQuestion!), findsOneWidget);
      expect(find.text('It showed up again'), findsOneWidget);
      expect(find.text('It felt lighter'), findsOneWidget);
      expect(find.text('It felt heavier'), findsOneWidget);
      expect(find.text('Not today'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.todaysWatchForRecordCta), findsOneWidget);
      expect(saved, isNull);
    },
  );

  testWidgets('selecting It felt lighter shows follow-up prompt', (
    tester,
  ) async {
    ReturnCaptureSelection? saved;
    final pending = _pending();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodaysWatchForCard(
            pending: pending,
            persistSelection: (selection) async => saved = selection,
            loadSelection: () async => null,
            trackActivation: false,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('It felt lighter'));
    await tester.pump();

    expect(find.text('What made it lighter today?'), findsOneWidget);
    expect(saved?.comparisonHint, ReturnCaptureComparisonHints.lighter);
    expect(saved?.selectedQuickAnswerId, 'felt_lighter');
    expect(saved?.watchForId, pending.id);
  });
}