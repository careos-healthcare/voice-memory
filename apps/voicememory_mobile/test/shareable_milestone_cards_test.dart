import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_copy.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_engine.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_gates.dart';
import 'package:voicememory_mobile/features/milestone_share/milestone_share_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/milestone_share_card.dart';

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
  "don't miss",
  'subscribe now',
  'buy now',
  'must upgrade',
  'share to unlock',
  'you must',
  'voice memory',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'pro is active',
  'voicememory',
];

const _privateSnippet = 'felt pressure at work before saying yes';
const _privateName = 'Alexandra';

JournalEntry _entry(
  String id, {
  String? transcript,
  DateTime? createdAt,
  List<String> recurringThemes = const ['work'],
}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
      transcript: transcript ??
          'I $_privateSnippet again even when I was tired today.',
      durationSeconds: 30,
      localAudioPath: '/tmp/$id.m4a',
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: recurringThemes,
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up in this moment.',
        repeatedSignal: '',
      ),
    );

List<JournalEntry> _entries(
  int count, {
  List<String> recurringThemes = const ['work'],
}) =>
    List.generate(
      count,
      (i) => _entry(
        'e$i',
        createdAt: DateTime(2026, 6, 9 + i, 12),
        recurringThemes: recurringThemes,
      ),
    );

List<JournalEntry> _entriesAcrossDays(int count) => List.generate(
      count,
      (i) => _entry(
        'd$i',
        createdAt: DateTime(2026, 6, 1 + i, 12),
      ),
    );

MilestoneShareInput _input({
  int realSavedMomentCount = 0,
  int usableEvidenceCount = 0,
  bool firstWeekComplete = false,
  bool hasWatchTheme = false,
  bool weeklyReviewAvailable = false,
  bool weeklyReviewCompleted = false,
  bool hasRepeatingTheme = false,
  bool thenVsNowAvailable = false,
  bool archiveCalendarActiveAcrossDays = false,
}) =>
    MilestoneShareInput(
      realSavedMomentCount: realSavedMomentCount,
      usableEvidenceCount: usableEvidenceCount,
      firstWeekComplete: firstWeekComplete,
      hasWatchTheme: hasWatchTheme,
      weeklyReviewAvailable: weeklyReviewAvailable,
      weeklyReviewCompleted: weeklyReviewCompleted,
      hasRepeatingTheme: hasRepeatingTheme,
      thenVsNowAvailable: thenVsNowAvailable,
      archiveCalendarActiveAcrossDays: archiveCalendarActiveAcrossDays,
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
  }
}

void _expectNoPrivateContent(MilestoneShareCard card) {
  for (final field in [card.title, card.body, card.safeShareText, card.proofLabel]) {
    expect(field.toLowerCase(), isNot(contains(_privateSnippet)));
    expect(field.toLowerCase(), isNot(contains(_privateName.toLowerCase())));
    expect(field, isNot(contains('transcript')));
  }
}

ArchiveHomePriorityInput _priorityInput({
  int savedEntryCount = 3,
  bool milestoneShareVisible = true,
  bool reviewRitualVisible = false,
  bool thenVsNowVisible = false,
  bool archiveCalendarVisible = false,
}) =>
    ArchiveHomePriorityInput(
      savedEntryCount: savedEntryCount,
      usableEvidenceCount: savedEntryCount,
      depthLevel: ArchiveDepthLevel.notStarted,
      returnChangesAvailable: false,
      weeklyReviewAvailable: false,
      sampleMode: false,
      proPreviewPromoVisible: false,
      showEmptySample: false,
      firstWeekPathVisible: savedEntryCount < 7,
      dailyArchiveExerciseVisible: true,
      archiveClarityProgressVisible: true,
      capacityLoopVisible: false,
      capacityCostLaterCheckinVisible: false,
      beforeYouSayYesPauseVisible: false,
      thenVsNowVisible: thenVsNowVisible,
      archiveCalendarVisible: archiveCalendarVisible,
      reviewRitualVisible: reviewRitualVisible,
      milestoneShareVisible: milestoneShareVisible,
    );

void main() {
  const engine = MilestoneShareEngine();

  group('MilestoneShareEngine', () {
    test('0 entries returns empty state', () {
      final result = engine.build(_input());
      expect(result.isEmpty, isTrue);
      expect(result.cards, isEmpty);
      expect(result.emptyBody, MilestoneShareCopy.emptyBody);
      expect(result.emptyCtaLabel, MilestoneShareCopy.saveMomentCta);
    });

    test('1 entry creates first saved moment milestone', () {
      final result = engine.build(_input(realSavedMomentCount: 1));
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.firstSavedMoment));
    });

    test('3 entries creates 3 moments milestone', () {
      final result = engine.build(_input(realSavedMomentCount: 3));
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.threeMomentsSaved));
    });

    test('first week complete creates first week milestone', () {
      final result = engine.build(
        _input(realSavedMomentCount: 7, firstWeekComplete: true),
      );
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.firstWeekPathComplete));
    });

    test('watch theme creates watch theme milestone', () {
      final result = engine.build(
        _input(realSavedMomentCount: 1, hasWatchTheme: true),
      );
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.firstWatchThemeChosen));
    });

    test('weekly review available creates weekly review milestone', () {
      final result = engine.build(
        _input(realSavedMomentCount: 5, weeklyReviewAvailable: true),
      );
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.firstWeeklyReview));
    });

    test('repeating theme creates repeating theme milestone', () {
      final result = engine.build(
        _input(realSavedMomentCount: 4, hasRepeatingTheme: true),
      );
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.firstRepeatingTheme));
    });

    test('Then vs Now available creates Then vs Now milestone', () {
      final result = engine.build(
        _input(realSavedMomentCount: 5, thenVsNowAvailable: true),
      );
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.firstThenVsNowAvailable));
    });

    test('calendar active across multiple days creates calendar milestone', () {
      final result = engine.build(
        _input(
          realSavedMomentCount: 4,
          archiveCalendarActiveAcrossDays: true,
        ),
      );
      expect(result.cards.map((c) => c.milestoneId),
          contains(MilestoneShareId.archiveCalendarActive));
    });

    test('primary milestone chooses strongest/latest meaningful card', () {
      final result = engine.build(
        _input(
          realSavedMomentCount: 7,
          firstWeekComplete: true,
          weeklyReviewAvailable: true,
          thenVsNowAvailable: true,
          archiveCalendarActiveAcrossDays: true,
        ),
      );
      expect(
        result.primaryCard?.milestoneId,
        MilestoneShareId.archiveCalendarActive,
      );
    });

    test('no raw journal text appears in card fields', () {
      final entries = _entries(3);
      final result = engine.buildFromJournal(entries: entries, hasWatchTheme: false);
      for (final card in result.cards) {
        _expectNoPrivateContent(card);
      }
    });

    test('repeating theme detection excludes theme text from share copy', () {
      final entries = [
        _entry('a', recurringThemes: ['pressure at work']),
        _entry('b', recurringThemes: ['pressure at work']),
      ];
      final result = engine.buildFromJournal(entries: entries, hasWatchTheme: false);
      final repeating = result.cards
          .firstWhere((c) => c.milestoneId == MilestoneShareId.firstRepeatingTheme);
      expect(repeating.safeShareText.toLowerCase(), isNot(contains('pressure at work')));
      _expectNoPrivateContent(repeating);
    });

    test('sample/demo entries are excluded from journal build', () {
      final entries = [
        _entry('real'),
        JournalEntry(
          id: 'sample_archive_demo',
          createdAt: DateTime(2026, 6, 1),
          transcript: '[sample] Demo moment only.',
          durationSeconds: 1,
          localAudioPath: '',
          reflection: const Reflection(
            mood: '',
            emotionalIntensity: 0,
            recurringThemes: [],
            exactLanguagePattern: '',
            concreteObservation: '',
            repeatedSignal: '',
          ),
        ),
      ];
      final result = engine.buildFromJournal(entries: entries, hasWatchTheme: false);
      expect(result.totalAvailableCount, 1);
      expect(result.primaryCard?.milestoneId, MilestoneShareId.firstSavedMoment);
    });

    test('copy uses ArchiveMe and avoids VoiceMemory branding', () {
      _expectNoBannedCopy(MilestoneShareCopy.allVisibleStrings);
      expect(
        MilestoneShareCopy.shareTextFor(
          engine.build(_input(realSavedMomentCount: 1)).primaryCard!,
        ),
        contains('ArchiveMe'),
      );
      expect(
        MilestoneShareCopy.allVisibleStrings.join(' ').toLowerCase(),
        isNot(contains('voicememory')),
      );
    });
  });

  group('MilestoneShareGates', () {
    test('Archive Home shows card only when safe', () {
      expect(
        MilestoneShareGates.showOnArchiveHome(
          realSavedMomentCount: 0,
          milestoneCount: 0,
          sampleMode: false,
        ),
        isFalse,
      );
      expect(
        MilestoneShareGates.showOnArchiveHome(
          realSavedMomentCount: 1,
          milestoneCount: 1,
          sampleMode: false,
        ),
        isTrue,
      );
      expect(
        MilestoneShareGates.showOnArchiveHome(
          realSavedMomentCount: 3,
          milestoneCount: 2,
          sampleMode: true,
        ),
        isFalse,
      );
    });
  });

  group('Archive Home priority', () {
    const priorityEngine = ArchiveHomePriorityEngine();

    test('milestone share card does not displace core sticky cards', () {
      final plan = priorityEngine.build(_priorityInput(savedEntryCount: 5));
      expect(plan.primarySections, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(plan.primarySections, isNot(contains(ArchiveHomeSectionId.milestoneShare)));
    });

    test('milestone share ranks after review ritual when both visible', () {
      final plan = priorityEngine.build(
        _priorityInput(
          savedEntryCount: 5,
          reviewRitualVisible: true,
          milestoneShareVisible: true,
          thenVsNowVisible: false,
          archiveCalendarVisible: true,
        ),
      );
      final reviewIndex =
          plan.secondarySections.indexOf(ArchiveHomeSectionId.reviewRitual);
      final shareIndex =
          plan.secondarySections.indexOf(ArchiveHomeSectionId.milestoneShare);
      expect(reviewIndex, isNot(-1));
      expect(shareIndex, isNot(-1));
      expect(reviewIndex, lessThan(shareIndex));
    });

    test('milestone share hidden with zero entries', () {
      final plan = priorityEngine.build(
        _priorityInput(savedEntryCount: 0, milestoneShareVisible: false),
      );
      expect(plan.isHidden(ArchiveHomeSectionId.milestoneShare), isTrue);
    });
  });

  group('Routing and copy action', () {
    test('route /milestone-share-cards works', () {
      expect(MilestoneShareCopy.route, '/milestone-share-cards');
      expect(
        SensitiveRoutes.isSensitiveRoute('/milestone-share-cards'),
        isTrue,
      );
    });

    test('copy action works', () {
      const card = MilestoneShareCard(
        milestoneId: MilestoneShareId.firstSavedMoment,
        title: 'First saved moment',
        body: 'Your archive started with one honest save.',
        safeShareText: 'I saved my first moment in ArchiveMe.',
        proofLabel: '1 moment saved',
        ctaLabel: MilestoneShareCopy.saveMomentCta,
        ctaRoute: MilestoneShareCopy.recordRoute,
        isShareable: true,
        evidenceCountLabel: '1 moment saved',
        createdFromCountsOnly: true,
        rank: 1,
      );
      final shareText = MilestoneShareCopy.shareTextFor(card);
      expect(shareText, contains('I saved my first moment in ArchiveMe.'));
      expect(shareText, contains('No private entries shared.'));
      expect(shareText.toLowerCase(), isNot(contains(_privateSnippet)));
    });

    testWidgets('Archive Home card renders when milestones exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MilestoneShareHomeCard.test(
              entries: _entries(3),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('milestone_share_card')), findsOneWidget);
      expect(find.text(MilestoneShareCopy.openMilestoneCardsCta), findsOneWidget);
    });
  });

  test('router source contains milestone share route', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();
    expect(router, contains("path: '/milestone-share-cards'"));
    expect(router, contains("path != '/milestone-share-cards'"));
  });
}
