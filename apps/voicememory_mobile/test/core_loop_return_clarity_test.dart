import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_three_session_gates.dart';
import 'package:voicememory_mobile/features/archive_proof/archive_first_comparison_display.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_memory/daily_archive_memory_model.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_engine.dart';
import 'package:voicememory_mobile/features/onboarding/record_return_pro_state.dart';
import 'package:voicememory_mobile/features/retention/first_week_progress_copy.dart';
import 'package:voicememory_mobile/features/retention/first_week_progress_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/first_save_evidence_card.dart';
import 'package:voicememory_mobile/widgets/record/daily_archive_memory_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript,
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

const _homeworkBanned = [
  'Day 1 of 7',
  'check tomorrow',
  '1 of 3',
];

void _expectNoHomeworkCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final banned in _homeworkBanned) {
      expect(
        lower,
        isNot(contains(banned.toLowerCase())),
        reason: 'must not contain "$banned" in "$text"',
      );
    }
  }
}

List<String> _visibleText(WidgetTester tester) {
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final data = (element.widget as Text).data;
    if (data != null && data.isNotEmpty) texts.add(data);
  }
  return texts;
}

void main() {
  group('first save return clarity', () {
    test('first-save copy tells user when to return', () {
      expect(
        RecordReturnProCopy.evidenceBody,
        VisibleArchiveProofCopy.firstSavePostSaveBody,
      );
      expect(
        RecordReturnProCopy.evidenceBody,
        'Come back when this shows up again.',
      );
      expect(
        RecordReturnProCopy.evidenceSecondLine,
        contains('If it repeats, changes, fades, or disappears'),
      );
      expect(
        RecordReturnProCopy.evidenceSecondLine,
        contains('You do not need to keep working on this now'),
      );
      expect(RecordReturnProCopy.evidenceRecordAnother, 'Record if it happens again');
    });

    test('first-save path suppresses noisy homework cards', () {
      expect(
        FirstThreeSessionGates.suppressNoisyPostSaveCards(
          justSavedFirst: true,
          entryCount: 1,
        ),
        isTrue,
      );
    });

    test('first week progress skips day 1 program line for one entry', () {
      final now = DateTime(2026, 6, 12, 14);
      final progress = FirstWeekProgressEngine.buildPostSave(
        entries: [
          _entry(
            id: '1',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
            createdAt: now,
          ),
        ],
        firstProofUnlocked: false,
        now: now,
      );
      expect(progress, isNull);
      expect(FirstWeekProgressCopy.day1Title, 'Day 1 of 7');
    });

    testWidgets('first-save card shows return-when copy without homework', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FirstSaveEvidenceCard(
              onViewArchive: () {},
              onRecordAnother: () {},
              onDoneForToday: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Come back when this shows up again.'), findsOneWidget);
      expect(
        find.text(VisibleArchiveProofCopy.firstSavePostSaveReassurance),
        findsOneWidget,
      );
      expect(find.text('Done for today'), findsOneWidget);
      _expectNoHomeworkCopy(_visibleText(tester));
    });
  });

  group('one entry Archive copy', () {
    test('patterns one-entry body avoids generic add-more framing', () {
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedBody,
        VisibleArchiveProofCopy.patternsOneEntryBody,
      );
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedBody,
        'Come back when this shows up again.',
      );
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedCta,
        'Record if it happens again',
      );
      expect(
        ConsumerUiCopy.patternsFirstEntrySavedHelper,
        contains('If it repeats, changes, fades, or disappears'),
      );
    });

    test('early repeat one-moment progress avoids program counter', () {
      final progress = EarlyRepeatProgressEngine.build(
        entries: [
          _entry(
            id: '1',
            transcript: 'A quiet moment about lunch with a friend today.',
          ),
        ],
      );
      expect(progress, isNotNull);
      expect(progress!.progressLabel, isEmpty);
      expect(progress.body, EarlyRepeatProgressCopy.oneMomentBody);
      expect(
        progress.nextMomentCue.body,
        EarlyRepeatProgressCopy.oneMomentCueBodyFallback,
      );
    });
  });

  group('returning Record watch target', () {
    testWidgets('watch target asks whether the thread came back', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DailyArchiveMemoryCard(
              memory: const DailyArchiveMemoryResult(
                title: DailyArchiveMemoryCopy.watchTitle,
                body: DailyArchiveMemoryCopy.watchBody,
                watchPhrase: 'checking again',
                footer: DailyArchiveMemoryCopy.footer,
                hasWatchTarget: true,
                canShowPatternDetail: false,
              ),
              entryCount: 3,
              source: 'record',
              showFocusedCaptureActions: true,
              onRecord: () {},
              onTypeInstead: () {},
              onNotToday: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Did this come back?'), findsOneWidget);
      expect(
        find.text('Last time, this was the thread to watch:'),
        findsOneWidget,
      );
      expect(find.text('"checking again"'), findsOneWidget);
      expect(
        find.text(
          'Record if it came back, changed, faded, or disappeared.',
        ),
        findsOneWidget,
      );
      expect(find.text('Record what happened'), findsOneWidget);
      expect(find.text(ConsumerUiCopy.recordTitle), findsNothing);
    });
  });

  group('comparison copy', () {
    test('grounded comparison uses cautious language', () {
      final display = ArchiveFirstComparisonDisplay.resolve([
        _entry(
          id: 'a',
          transcript:
              'I had no capacity but I said yes again to the extra meeting today.',
        ),
        _entry(
          id: 'b',
          transcript:
              'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ]);

      expect(display.show, isTrue);
      expect(
        display.title,
        VisibleArchiveProofCopy.archiveFirstComparisonTitle,
      );
      expect(display.hasGroundedPattern, isTrue);
      expect(display.evidenceLine, isNotNull);
      expect(
        [
          VisibleArchiveProofCopy.archiveFirstComparisonMentionedBefore,
          VisibleArchiveProofCopy.archiveFirstComparisonMayConnectBody,
          VisibleArchiveProofCopy.archiveFirstComparisonCautionThin,
        ],
        contains(display.body),
      );
    });

    test('weak comparison fallback does not claim a repeat', () {
      final display = ArchiveFirstComparisonDisplay.resolve([
        _entry(
          id: 'a',
          transcript: 'A quiet moment about lunch with a friend today.',
        ),
        _entry(
          id: 'b',
          transcript: 'Another unrelated note about errands this afternoon.',
          createdAt: DateTime(2026, 6, 13, 12),
        ),
      ]);

      expect(display.show, isTrue);
      expect(display.title, VisibleArchiveProofCopy.twoEntryCompareTitle);
      expect(display.body, VisibleArchiveProofCopy.twoEntryBodyUngrounded);
      expect(display.evidenceLine, isNull);
      expect(display.hasGroundedPattern, isFalse);
      expect(display.title, isNot(contains('came back')));
    });
  });
}
