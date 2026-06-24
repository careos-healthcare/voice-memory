import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_calendar/archive_calendar_copy.dart';
import 'package:voicememory_mobile/features/archive_calendar/archive_calendar_engine.dart';
import 'package:voicememory_mobile/features/archive_calendar/archive_calendar_models.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_calendar_card.dart';

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
  const engine = ArchiveCalendarEngine();
  final now = DateTime(2026, 6, 15, 12);

  group('ArchiveCalendarEngine', () {
    test('0 entries returns empty state', () {
      final result = engine.buildFromJournal(entries: const [], now: now);
      expect(result.isEmpty, isTrue);
      expect(result.hasCard, isFalse);
      expect(result.primaryCtaLabel, ArchiveCalendarCopy.saveMomentCta);
    });

    test('1 entry creates one calendar day', () {
      final result = engine.buildFromJournal(
        entries: [
          _entry('one', createdAt: DateTime(2026, 6, 10)),
        ],
        now: now,
      );
      expect(result.isEmpty, isFalse);
      expect(result.days, hasLength(1));
      expect(result.days.single.momentCount, 1);
    });

    test('multiple entries same day aggregate count', () {
      final result = engine.buildFromJournal(
        entries: [
          _entry('a', createdAt: DateTime(2026, 6, 10, 9)),
          _entry('b', createdAt: DateTime(2026, 6, 10, 18)),
        ],
        now: now,
      );
      expect(result.days.single.momentCount, 2);
      expect(
        result.days.single.markerLabels,
        contains(ArchiveCalendarCopy.markerMultipleMoments),
      );
    });

    test('entries across days produce sorted day summaries', () {
      final result = engine.buildFromJournal(
        entries: [
          _entry('older', createdAt: DateTime(2026, 6, 8)),
          _entry('newer', createdAt: DateTime(2026, 6, 12)),
        ],
        now: now,
      );
      expect(result.days, hasLength(2));
      expect(result.days.first.date.isAfter(result.days.last.date), isTrue);
    });

    test('today marker works with injected date', () {
      final result = engine.buildFromJournal(
        entries: [
          _entry('today', createdAt: DateTime(2026, 6, 15, 8)),
        ],
        now: now,
      );
      expect(result.days.single.isToday, isTrue);
    });

    test('most active day uses counts only', () {
      final result = engine.buildFromJournal(
        entries: [
          _entry('a', createdAt: DateTime(2026, 6, 8)),
          _entry('b', createdAt: DateTime(2026, 6, 10)),
          _entry('c', createdAt: DateTime(2026, 6, 10, 12)),
        ],
        now: now,
      );
      final busiest = result.days.firstWhere((day) => day.momentCount == 2);
      expect(busiest.isMostActiveDay, isTrue);
      expect(result.mostActiveDayLabel, contains('10 June 2026'));
    });

    test('sample entries are excluded', () {
      final result = engine.buildFromJournal(
        entries: [
          _entry('real', createdAt: DateTime(2026, 6, 10)),
          ...SampleArchiveEntries.build(),
        ],
        now: now,
      );
      expect(result.totalMomentCount, 1);
      expect(result.days, hasLength(1));
    });

    test('no raw journal text appears in model output', () {
      const privateText = 'My private journal detail that should never appear';
      final result = engine.buildFromJournal(
        entries: [
          _entry(
            'private',
            createdAt: DateTime(2026, 6, 10),
            transcript: privateText,
          ),
        ],
        now: now,
      );
      final serialized = [
        result.cardHeadline,
        result.cardSummary,
        result.weekSummaryLabel,
        result.monthlyTotalLabel,
        result.mostActiveDayLabel,
        result.helperText,
        ...result.days.map((day) => day.dayLabel),
        ...result.days.expand((day) => day.markerLabels),
      ].join(' ');
      expect(serialized, isNot(contains(privateText)));
    });

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy = ArchiveCalendarCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(ArchiveCalendarCopy.allVisibleStrings);
    });
  });

  group('Archive Home integration', () {
    test('shows card only when user has real saved moments', () {
      final withEntries = engine.buildFromJournal(
        entries: [_entry('one', createdAt: DateTime(2026, 6, 10))],
        now: now,
      );
      expect(withEntries.showOnArchiveHome, isTrue);

      final withoutEntries = engine.buildFromJournal(entries: const [], now: now);
      expect(withoutEntries.showOnArchiveHome, isFalse);
    });

    test('does not displace First Week Path / Daily Exercise / Archive Clarity / Then vs Now', () {
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
          capacityCostLaterCheckinVisible: false,
          beforeYouSayYesPauseVisible: false,
          thenVsNowVisible: true,
          archiveCalendarVisible: true,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );

      expect(
        plan.secondarySections,
        contains(ArchiveHomeSectionId.archiveCalendar),
      );
      expect(
        plan.secondarySections.indexOf(ArchiveHomeSectionId.archiveCalendar),
        greaterThan(
          plan.secondarySections.indexOf(ArchiveHomeSectionId.thenVsNow),
        ),
      );
    });
  });

  group('ArchiveCalendarCard', () {
    testWidgets('renders compact calendar card', (tester) async {
      final result = engine.buildFromJournal(
        entries: [_entry('one', createdAt: DateTime(2026, 6, 10))],
        now: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveCalendarCard(result: result),
        ),
      );

      expect(find.byKey(const Key('archive_calendar_card')), findsOneWidget);
      expect(find.text(ArchiveCalendarCopy.eyebrow), findsOneWidget);
    });
  });

  group('Routing', () {
    test('router registers archive calendar route', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/archive-calendar'"));
    });

    test('sensitive route guard includes archive calendar', () {
      expect(SensitiveRoutes.isSensitiveRoute('/archive-calendar'), isTrue);
    });
  });

  group('Support & Feedback', () {
    test('support screen links to archive calendar route', () {
      final support =
          File('lib/screens/support_feedback_screen.dart').readAsStringSync();
      expect(support, contains('ArchiveCalendarCopy.route'));
      expect(support, contains('support_feedback_open_archive_calendar'));
    });
  });
}
