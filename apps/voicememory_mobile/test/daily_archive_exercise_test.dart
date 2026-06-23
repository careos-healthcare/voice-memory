import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_engine.dart';
import 'package:voicememory_mobile/features/daily_archive_exercise/daily_archive_exercise_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/daily_archive_exercise_card.dart';
import 'package:voicememory_mobile/widgets/record/daily_archive_exercise_record_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'streak',
  'guilt',
  'certain',
  'addictive',
  'limited time',
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  "don't miss",
  'voice memory',
];

DailyArchiveExerciseInput _input({
  int realSavedMomentCount = 0,
  bool hasWatchTheme = false,
  bool betaFeedbackCaptured = false,
  bool sampleMode = false,
  int dayIndex = 1,
}) =>
    DailyArchiveExerciseInput(
      realSavedMomentCount: realSavedMomentCount,
      hasWatchTheme: hasWatchTheme,
      betaFeedbackCaptured: betaFeedbackCaptured,
      sampleMode: sampleMode,
      dayIndex: dayIndex,
    );

JournalEntry _entry(String id, {String? transcript}) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript: transcript ??
          'I noticed the same work pressure pattern when I said yes again today.',
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

List<JournalEntry> _realEntries(int count) => List.generate(
      count,
      (i) => _entry('real_$i'),
    );

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
    expect(lower, isNot(contains('voicememory')));
  }
}

void main() {
  const engine = DailyArchiveExerciseEngine();

  group('DailyArchiveExerciseEngine', () {
    test('0 entries gives first-moment exercise', () {
      final result = engine.build(_input());

      expect(result.kind, DailyArchiveExerciseKind.firstMoment);
      expect(result.prompt, DailyArchiveExerciseCopy.firstMomentPrompt);
      expect(result.primaryRoute, '/record');
    });

    test('1–2 entries asks for comparison material', () {
      final one = engine.build(_input(realSavedMomentCount: 1));
      final two = engine.build(_input(realSavedMomentCount: 2));

      expect(one.kind, DailyArchiveExerciseKind.comparisonMaterial);
      expect(two.kind, DailyArchiveExerciseKind.comparisonMaterial);
      expect(one.prompt, DailyArchiveExerciseCopy.comparisonPrompt);
      expect(two.primaryRoute, '/record');
    });

    test('3+ entries can point to beta feedback', () {
      final result = engine.build(
        _input(
          realSavedMomentCount: 3,
          betaFeedbackCaptured: false,
        ),
      );

      expect(result.kind, DailyArchiveExerciseKind.betaFeedback);
      expect(result.primaryRoute, '/beta-feedback');
    });

    test('watch theme present gives watch-theme exercise', () {
      final result = engine.build(
        _input(
          realSavedMomentCount: 4,
          hasWatchTheme: true,
          betaFeedbackCaptured: true,
        ),
      );

      expect(result.kind, DailyArchiveExerciseKind.watchTheme);
      expect(result.prompt, DailyArchiveExerciseCopy.watchThemePrompt);
      expect(result.primaryRoute, '/record');
    });

    test('sample entries are excluded from real counts', () {
      final entries = [
        ..._realEntries(2),
        ...SampleArchiveEntries.build(),
      ];
      expect(engine.realSavedMomentCount(entries), 2);
    });

    test('ScreenshotMode preview does not expose private data', () {
      final result = engine.build(_input(sampleMode: true));

      expect(result.showOnArchiveHome, isFalse);
      expect(result.showOnRecord, isFalse);
      expect(result.prompt, contains('Example only'));
      for (final entry in _realEntries(3)) {
        expect(result.prompt, isNot(contains(entry.transcript)));
      }
    });

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy =
          DailyArchiveExerciseCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(DailyArchiveExerciseCopy.allVisibleStrings);
    });

    test('engine does not include raw journal text in output', () {
      final entries = _realEntries(2);
      final privateText = entries.first.transcript;
      final result = engine.buildFromJournal(
        entries: entries,
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );

      expect(result.prompt, isNot(contains(privateText)));
      expect(result.hint, isNot(contains(privateText)));
    });
  });

  group('Archive Home integration', () {
    test('early users rank daily archive exercise on Archive Home', () {
      final plan = const ArchiveHomePriorityEngine().build(
        ArchiveHomePriorityInput(
          savedEntryCount: 1,
          usableEvidenceCount: 1,
          depthLevel: ArchiveDepthLevel.firstEvidence,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: true,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          thenVsNowVisible: false,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );

      expect(
        plan.primarySections.contains(ArchiveHomeSectionId.dailyArchiveExercise) ||
            plan.secondarySections.contains(
              ArchiveHomeSectionId.dailyArchiveExercise,
            ),
        isTrue,
      );
    });

    testWidgets('Archive Home shows compact card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: DailyArchiveExerciseCard.test(
            entries: _realEntries(1),
            initialResult: engine.build(_input(realSavedMomentCount: 1)),
          ),
        ),
      );

      expect(find.byKey(const Key('daily_archive_exercise_card')), findsOneWidget);
      expect(
        find.text(DailyArchiveExerciseCopy.comparisonPrompt),
        findsOneWidget,
      );
    });
  });

  group('Record screen card', () {
    testWidgets('Record prompt works when enabled', (tester) async {
      final exercise = engine.build(_input(realSavedMomentCount: 0));
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: DailyArchiveExerciseRecordCard(
            exercise: exercise,
            onPrimary: () => tapped = true,
          ),
        ),
      );

      expect(
        find.byKey(const Key('daily_archive_exercise_record_card')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('daily_archive_exercise_record_primary_button')),
      );
      expect(tapped, isTrue);
    });
  });

  group('Routing', () {
    test('router registers daily archive exercise route', () {
      final router =
          File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/daily-archive-exercise'"));
    });
  });
}
