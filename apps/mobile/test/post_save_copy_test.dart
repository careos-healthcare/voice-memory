import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_engine.dart';
import 'package:archiveme_mobile/features/tomorrow_return/tomorrow_return_loop_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:archiveme_mobile/widgets/potential_signals_card.dart';
import 'package:archiveme_mobile/widgets/record/today_noticed_post_save_card.dart';
import 'package:archiveme_mobile/widgets/record/tomorrow_return_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _testDay = DateTime(2026, 6, 6);

JournalEntry _entryWithObservation(String observation) {
  return JournalEntry(
    id: 'e1',
    createdAt: DateTime(2026, 6, 6, 12),
    transcript: '',
    durationSeconds: 30,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 3,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: observation,
      repeatedSignal: '',
    ),
  );
}

void main() {
  test(
    'return loop engine hides legacy cloud observation from noticed copy',
    () {
      const engine = TomorrowReturnLoopEngine();
      final loop = engine.build(
        entries: [
          _entryWithObservation(
            'Saved on this device. Cloud processing pending.',
          ),
        ],
        now: DateTime(2026, 6, 6, 14),
      );

      expect(loop.noticedToday, ConsumerUiCopy.savedPrivatelyOnDevice);
      expect(
        loop.noticedToday.toLowerCase(),
        isNot(contains('cloud processing')),
      );
      expect(loop.noticedToday.toLowerCase(), isNot(contains('voicememory')));
    },
  );

  test('return loop watch-for uses neutral prompt for system observations', () {
    const engine = TomorrowReturnLoopEngine();
    final loop = engine.build(
      entries: [
        _entryWithObservation(
          'Saved on this device. Cloud processing pending.',
        ),
      ],
      now: DateTime(2026, 6, 6, 14),
    );

    expect(loop.watchForNextTime, ConsumerUiCopy.tomorrowNoticePrompt);
    for (final chip in loop.displayWatchChips) {
      expect(chip.toLowerCase(), isNot(contains('cloud processing')));
      expect(chip.toLowerCase(), isNot(contains('saved on this device')));
    }
  });

  testWidgets('post-save cards use ArchiveMe copy and hide cloud strings', (
    tester,
  ) async {
    final loop = TomorrowReturnLoop(
      noticedToday: 'You mentioned pressure before saying yes.',
      comeBackTomorrow: 'Come back tomorrow to see what repeats.',
      watchForNextTime: ConsumerUiCopy.tomorrowNoticePrompt,
      generatedAt: _testDay,
      watchForChips: const ['same worry', 'same person'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              TodayNoticedPostSaveCard(loop: loop),
              TomorrowReturnCard(loop: loop),
              const PotentialSignalsCard(
                signals: [],
                noticedToday: 'You mentioned pressure before saying yes.',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text(ConsumerUiCopy.todayArchiveMeNoticed), findsNWidgets(2));
    expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsNothing);
    expect(find.textContaining('Cloud processing pending'), findsNothing);
    expect(find.textContaining('Cloud sync is unavailable'), findsNothing);
    expect(find.textContaining('VoiceMemory'), findsNothing);
    expect(find.text(ConsumerUiCopy.viewPatternsCta), findsOneWidget);
  });

  testWidgets(
    'post-save hides Today noticed card when noticed copy is system-only',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text(CaptureSaveMessages.savedPrivatelyOnDevice),
                TodayNoticedPostSaveCard(
                  loop: TomorrowReturnLoop(
                    noticedToday: ConsumerUiCopy.savedPrivatelyOnDevice,
                    comeBackTomorrow: 'Come back tomorrow.',
                    watchForNextTime: ConsumerUiCopy.tomorrowNoticePrompt,
                    generatedAt: _testDay,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text(ConsumerUiCopy.savedPrivatelyOnDevice), findsOneWidget);
      expect(find.text(ConsumerUiCopy.todayArchiveMeNoticed), findsNothing);
      expect(find.textContaining('Cloud processing pending'), findsNothing);
      expect(find.textContaining('Today VoiceMemory noticed'), findsNothing);
    },
  );

  testWidgets('today noticed card hidden for system observation leak', (
    tester,
  ) async {
    final loop = TomorrowReturnLoop(
      noticedToday: 'Saved on this device. Cloud processing pending.',
      comeBackTomorrow: 'Come back tomorrow.',
      watchForNextTime: ConsumerUiCopy.tomorrowNoticePrompt,
      generatedAt: _testDay,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TodayNoticedPostSaveCard(loop: loop)),
      ),
    );

    expect(find.text(ConsumerUiCopy.todayArchiveMeNoticed), findsNothing);
    expect(find.textContaining('Cloud processing pending'), findsNothing);
  });
}