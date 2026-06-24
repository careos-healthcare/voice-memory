import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/then_now/then_now_copy.dart';
import 'package:voicememory_mobile/features/then_now/then_now_engine.dart';
import 'package:voicememory_mobile/features/then_now/then_now_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/then_vs_now_card.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
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
  'you must',
  'you always',
  'you never',
  'proves',
  'voice memory',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'pro is active',
];

Reflection _reflection({List<String> themes = const ['work']}) =>
    Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: themes,
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up in this moment.',
      repeatedSignal: '',
    );

JournalEntry _entry(
  String id, {
  required DateTime createdAt,
  List<String> themes = const ['work'],
  String? transcript,
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt,
      transcript: transcript ??
          'I noticed the same work pressure pattern when I said yes again today.',
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: _reflection(themes: themes),
    );

List<JournalEntry> _entriesWithThemes(int count) => List.generate(
      count,
      (i) => _entry(
        'real_$i',
        createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
      ),
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
  const engine = ThenNowEngine();

  group('ThenNowEngine', () {
    test('0 entries returns no card', () {
      final result = engine.buildFromJournal(entries: const []);
      expect(result.hasCard, isFalse);
    });

    test('4 entries returns no card', () {
      final result = engine.buildFromJournal(entries: _entriesWithThemes(4));
      expect(result.hasCard, isFalse);
    });

    test('5 entries returns early preview', () {
      final result = engine.buildFromJournal(entries: _entriesWithThemes(5));
      expect(result.hasCard, isTrue);
      expect(result.reasonId, ThenNowReasonId.earlyPreview);
      expect(result.headline, ThenNowCopy.earlyHeadline);
    });

    test('7+ entries with repeated signal returns a card', () {
      final result = engine.buildFromJournal(entries: _entriesWithThemes(7));
      expect(result.hasCard, isTrue);
      expect(result.reasonId, ThenNowReasonId.themeComparison);
      expect(result.thenSummary, isNotEmpty);
      expect(result.nowSummary, isNotEmpty);
    });

    test('7+ entries with no repeated signal returns no card', () {
      final entries = List.generate(
        7,
        (i) => _entry(
          'unique_$i',
          createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          themes: ['theme_$i'],
        ),
      );
      final result = engine.buildFromJournal(entries: entries);
      expect(result.hasCard, isFalse);
      expect(result.reasonId, ThenNowReasonId.noClearChange);
    });

    test('earlier/newer split is chronological', () {
      final entries = _entriesWithThemes(7);
      final result = engine.buildFromJournal(entries: entries);
      expect(result.evidenceCountLabel, contains('earlier'));
      expect(result.evidenceCountLabel, contains('newer'));
    });

    test('sample entries are excluded', () {
      final entries = [
        ..._entriesWithThemes(5),
        ...SampleArchiveEntries.build(),
      ];
      final result = engine.buildFromJournal(entries: entries);
      expect(result.hasCard, isTrue);
      expect(result.reasonId, ThenNowReasonId.earlyPreview);
    });

    test('no raw transcript text appears in model output', () {
      const privateText = 'My private journal detail that should never appear';
      final entries = [
        _entry(
          'private',
          createdAt: DateTime(2026, 1, 1),
          transcript: privateText,
        ),
        ..._entriesWithThemes(6),
      ];
      final result = engine.buildFromJournal(entries: entries);
      expect(result.headline, isNot(contains(privateText)));
      expect(result.thenSummary, isNot(contains(privateText)));
      expect(result.nowSummary, isNot(contains(privateText)));
      expect(result.evidenceCountLabel, isNot(contains(privateText)));
    });

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy = ThenNowCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(ThenNowCopy.allVisibleStrings);
    });
  });

  group('Archive Home integration', () {
    test('shows card only when meaningful', () {
      final withCard = engine.buildFromJournal(entries: _entriesWithThemes(7));
      final withoutCard = engine.buildFromJournal(entries: _entriesWithThemes(2));

      expect(withCard.hasCard, isTrue);
      expect(withoutCard.hasCard, isFalse);
    });

    test('does not displace First Week Path / Daily Exercise / Archive Clarity', () {
      final plan = const ArchiveHomePriorityEngine().build(
        ArchiveHomePriorityInput(
          savedEntryCount: 8,
          usableEvidenceCount: 8,
          depthLevel: ArchiveDepthLevel.weeklyReviewReady,
          returnChangesAvailable: true,
          weeklyReviewAvailable: true,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: true,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityLoopVisible: false,
          capacityDecisionOutcomeVisible: false,
          capacityCostLaterCheckinVisible: false,
          beforeYouSayYesPauseVisible: false,
          thenVsNowVisible: true,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );

      expect(plan.secondarySections, contains(ArchiveHomeSectionId.thenVsNow));
      expect(
        plan.secondarySections.indexOf(ArchiveHomeSectionId.thenVsNow),
        greaterThan(
          plan.secondarySections.indexOf(ArchiveHomeSectionId.dailyArchiveExercise),
        ),
      );
      expect(
        plan.secondarySections.indexOf(ArchiveHomeSectionId.thenVsNow),
        greaterThan(
          plan.secondarySections.indexOf(ArchiveHomeSectionId.archiveClarityProgress),
        ),
      );
    });
  });

  group('ThenVsNowCard', () {
    testWidgets('renders compact comparison card', (tester) async {
      final result = engine.buildFromJournal(entries: _entriesWithThemes(7));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ThenVsNowCard(
            entries: _entriesWithThemes(7),
            result: result,
          ),
        ),
      );

      expect(find.byKey(const Key('then_vs_now_card')), findsOneWidget);
      expect(find.text(ThenNowCopy.comparisonHeadline), findsOneWidget);
    });
  });

  group('Routing', () {
    test('router registers then vs now route', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/then-vs-now'"));
    });

    test('sensitive route guard includes then vs now', () {
      expect(SensitiveRoutes.isSensitiveRoute('/then-vs-now'), isTrue);
    });
  });
}
