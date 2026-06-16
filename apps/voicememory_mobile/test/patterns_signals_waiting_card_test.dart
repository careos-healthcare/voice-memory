import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/post_save_insight/selected_signal_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/widgets/patterns/patterns_signals_waiting_card.dart';

SelectedSignalRecord _record() {
  return SelectedSignalRecord(
    id: 'sig_1',
    title: 'Carrying too much responsibility',
    categoryId: 'responsibility',
    strengthLabel: 'Early signal',
    nextPrompt: 'When did you next feel pressure to say yes?',
    savedAt: DateTime(2026, 6, 1),
    whySuggested: 'You mentioned saying yes and pressure.',
    evidenceChips: const ['saying yes', 'pressure'],
  );
}

void main() {
  testWidgets('selected signal appears on Patterns waiting card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternsSignalsWaitingCard(
            selected: _record(),
            reflectionCount: 1,
            nextPrompt: _record().nextPrompt,
          ),
        ),
      ),
    );

    expect(
      find.text(ConsumerUiCopy.patternsSignalsWaitingTitle),
      findsOneWidget,
    );
    expect(find.text('Carrying too much responsibility'), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.patternsWatchingSignalTitle),
      findsOneWidget,
    );
    expect(
      find.text(ConsumerUiCopy.patternsWatchingSignalBody),
      findsOneWidget,
    );
  });

  testWidgets('next prompt and progress appear', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternsSignalsWaitingCard(
            selected: _record(),
            reflectionCount: 2,
            nextPrompt: _record().nextPrompt,
          ),
        ),
      ),
    );

    expect(find.textContaining('2 of 3 moments'), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.patternsSignalsWaitingClarity),
      findsOneWidget,
    );
    expect(find.text(_record().nextPrompt), findsOneWidget);
  });

  testWidgets('no fake placeholder examples', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternsSignalsWaitingCard(
            selected: _record(),
            reflectionCount: 1,
            nextPrompt: _record().nextPrompt,
          ),
        ),
      ),
    );

    expect(find.textContaining('I want freedom'), findsNothing);
    expect(find.textContaining('I talk about achievement'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
  });
}
