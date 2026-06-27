import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_clarity/archive_clarity_copy.dart';
import 'package:voicememory_mobile/features/archive_clarity/archive_clarity_engine.dart';
import 'package:voicememory_mobile/features/archive_clarity/archive_clarity_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_copy.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/archive_clarity_progress_card.dart';
import 'package:voicememory_mobile/widgets/archive_home_more_tools_section.dart';

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
  'voice memory',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
];

ArchiveClarityInput _input({
  int realSavedMomentCount = 0,
  int usableEvidenceCount = 0,
  bool hasWatchTheme = false,
  bool betaFeedbackCaptured = false,
  bool weeklyReviewAvailable = false,
  bool sampleMode = false,
}) =>
    ArchiveClarityInput(
      realSavedMomentCount: realSavedMomentCount,
      usableEvidenceCount: usableEvidenceCount,
      hasWatchTheme: hasWatchTheme,
      betaFeedbackCaptured: betaFeedbackCaptured,
      weeklyReviewAvailable: weeklyReviewAvailable,
      sampleMode: sampleMode,
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

List<JournalEntry> _realEntries(int count) =>
    List.generate(count, (i) => _entry('real_$i'));

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
  const engine = ArchiveClarityEngine();

  group('ArchiveClarityEngine', () {
    test('0 entries returns Starting', () {
      final result = engine.build(_input());

      expect(result.stageId, ArchiveClarityStageId.starting);
      expect(result.stageLabel, ArchiveClarityCopy.stageStarting);
      expect(result.body, ArchiveClarityCopy.startingBody);
      expect(result.primaryRoute, '/record');
      expect(result.isEmpty, isTrue);
    });

    test('1 entry returns Comparison forming', () {
      final result = engine.build(_input(realSavedMomentCount: 1));

      expect(result.stageId, ArchiveClarityStageId.comparisonForming);
      expect(result.stageLabel, ArchiveClarityCopy.stageComparisonForming);
      expect(result.primaryRoute, '/record');
    });

    test('2 entries returns Comparison forming', () {
      final result = engine.build(_input(realSavedMomentCount: 2));

      expect(result.stageId, ArchiveClarityStageId.comparisonForming);
    });

    test('3 entries returns Pattern emerging', () {
      final result = engine.build(
        _input(realSavedMomentCount: 3, betaFeedbackCaptured: false),
      );

      expect(result.stageId, ArchiveClarityStageId.patternEmerging);
      expect(result.primaryRoute, '/beta-feedback');
    });

    test('4 entries returns Pattern emerging', () {
      final result = engine.build(
        _input(realSavedMomentCount: 4, betaFeedbackCaptured: true),
      );

      expect(result.stageId, ArchiveClarityStageId.patternEmerging);
      expect(result.primaryRoute, '/record');
    });

    test('5 entries returns Evidence growing', () {
      final result = engine.build(
        _input(realSavedMomentCount: 5, hasWatchTheme: false),
      );

      expect(result.stageId, ArchiveClarityStageId.evidenceGrowing);
      expect(result.primaryRoute, '/archive-belief');
    });

    test('6 entries returns Evidence growing', () {
      final result = engine.build(
        _input(realSavedMomentCount: 6, hasWatchTheme: true),
      );

      expect(result.stageId, ArchiveClarityStageId.evidenceGrowing);
      expect(result.primaryRoute, '/record');
    });

    test('7 entries returns Review ready', () {
      final result = engine.build(
        _input(realSavedMomentCount: 7, weeklyReviewAvailable: true),
      );

      expect(result.stageId, ArchiveClarityStageId.reviewReady);
      expect(result.isReviewReady, isTrue);
      expect(result.primaryRoute, '/weekly-archive-review');
    });

    test('usable evidence count influences evidence strength label', () {
      final withUsable = engine.build(
        _input(realSavedMomentCount: 3, usableEvidenceCount: 2),
      );
      final withoutUsable = engine.build(
        _input(realSavedMomentCount: 3, usableEvidenceCount: 3),
      );

      expect(withUsable.evidenceStrengthValue, contains('usable'));
      expect(withoutUsable.evidenceStrengthValue, '3 of 7 moments');
    });

    test('sample entries are excluded from real counts', () {
      final entries = [
        ..._realEntries(2),
        ...SampleArchiveEntries.build(),
      ];
      expect(engine.realSavedMomentCount(entries), 2);
    });

    test('engine does not include raw journal text in output', () {
      final entries = _realEntries(2);
      final privateText = entries.first.transcript;
      final result = engine.buildFromJournal(
        entries: entries,
        usableEvidenceCount: 2,
        hasWatchTheme: false,
        betaFeedbackCaptured: false,
      );

      expect(result.body, isNot(contains(privateText)));
      expect(result.nextStepText, isNot(contains(privateText)));
      expect(result.evidenceStrengthValue, isNot(contains(privateText)));
    });

    test('ScreenshotMode preview does not expose private data', () {
      final result = engine.build(_input(sampleMode: true));

      expect(result.showOnArchiveHome, isFalse);
      expect(result.body, contains('Example only'));
    });

    test('copy uses ArchiveMe and avoids banned language', () {
      final copy =
          ArchiveClarityCopy.allVisibleStrings.join(' ').toLowerCase();
      expect(copy, contains('archiveme'));
      _expectNoBannedCopy(ArchiveClarityCopy.allVisibleStrings);
    });
  });

  group('Archive Home integration', () {
    test('early users rank clarity without crowding First Week Path', () {
      final plan = const ArchiveHomePriorityEngine().build(
        ArchiveHomePriorityInput(
          savedEntryCount: 0,
          usableEvidenceCount: 0,
          depthLevel: ArchiveDepthLevel.notStarted,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: true,
          firstWeekPathVisible: true,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityLoopVisible: false,
          capacityThreeMomentActivationVisible: false,
          capacityPullReasonVisible: false,
          capacityDecisionOutcomeVisible: false,
          capacityCostLaterCheckinVisible: false,
          capacityActivationFitVisible: false,
          beforeYouSayYesPauseVisible: false,
          capacityWeeklyReviewVisible: false,
          capacityBoundaryResponseVisible: false,
          thenVsNowVisible: false,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );

      expect(plan.primarySections, contains(ArchiveHomeSectionId.firstWeekPath));
      expect(plan.primarySections, contains(ArchiveHomeSectionId.dailyArchiveExercise));
      expect(
        plan.primarySections.indexOf(ArchiveHomeSectionId.firstWeekPath),
        lessThan(
          plan.primarySections.indexOf(ArchiveHomeSectionId.dailyArchiveExercise),
        ),
      );
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(
        ranked.indexOf(ArchiveHomeSectionId.dailyArchiveExercise),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.archiveClarityProgress)),
      );
    });

    testWidgets('Archive Home shows compact clarity card', (tester) async {
      final result = engine.build(_input(realSavedMomentCount: 1));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveClarityProgressCard.test(
            entries: _realEntries(1),
            initialResult: result,
          ),
        ),
      );

      expect(find.byKey(const Key('archive_clarity_progress_card')), findsOneWidget);
      expect(find.text(ArchiveClarityCopy.stageComparisonForming), findsOneWidget);
    });
  });

  group('More archive tools', () {
    testWidgets('expands secondary tools when the card is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ArchiveHomeMoreToolsSection(
              children: const [
                Text('Secondary archive tool'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('more_archive_tools_card')), findsOneWidget);
      expect(
        find.byKey(const Key('more_archive_tools_expanded_content')),
        findsNothing,
      );
      expect(find.text('Secondary archive tool'), findsNothing);

      await tester.tap(find.text(ArchiveHomePriorityCopy.moreArchiveToolsTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const Key('more_archive_tools_expanded_content')),
        findsOneWidget,
      );
      expect(find.text('Secondary archive tool'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });
  });

  group('Routing', () {
    test('router registers archive clarity route', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/archive-clarity-progress'"));
    });

    test('sensitive route guard includes archive clarity', () {
      expect(
        SensitiveRoutes.isSensitiveRoute('/archive-clarity-progress'),
        isTrue,
      );
    });

    test('support feedback links to archive clarity when implemented', () {
      final support =
          File('lib/screens/support_feedback_screen.dart').readAsStringSync();
      expect(support, contains('support_feedback_open_archive_clarity'));
      expect(support, contains('ArchiveClarityCopy.route'));
    });
  });
}
