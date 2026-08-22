import 'package:archiveme_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:archiveme_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:archiveme_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_return_trigger_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_return_trigger_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_return_trigger_models.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_three_moment_copy.dart';
import 'package:archiveme_mobile/features/capacity_loop/capacity_three_moment_engine.dart';
import 'package:archiveme_mobile/features/capacity_loop/low_effort_yes_capture_copy.dart';
import 'package:archiveme_mobile/features/demo/sample_archive_entries.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/capacity_return_trigger_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
  "don't forget",
  'you must',
  'daily habit',
  'failure',
  'missed',
  'complete your streak',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(String id, {String? transcript}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I $_privateSnippet again and said yes with no capacity left.',
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
    expect(lower, isNot(contains('archiveme knows')));
    expect(lower, isNot(contains(_privateSnippet)));
  }
}

void main() {
  const engine = CapacityReturnTriggerEngine();
  const threeMomentEngine = CapacityThreeMomentEngine();

  group('CapacityReturnTriggerEngine', () {
    test('shows completion copy after first capacity moment', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        surface: CapacityReturnTriggerSurface.completion,
      );
      expect(result.showCard, isTrue);
      expect(result.title, CapacityReturnTriggerCopy.completionTitle);
      expect(result.body, CapacityReturnTriggerCopy.completionBody);
      expect(
        result.primaryCtaLabel,
        CapacityReturnTriggerCopy.completionPrimaryCta,
      );
      expect(
        result.secondaryCtaLabel,
        CapacityReturnTriggerCopy.completionSecondaryCta,
      );
    });

    test('hides completion after second moment', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        surface: CapacityReturnTriggerSurface.completion,
      );
      expect(result.showCard, isFalse);
    });

    test('archive home copy for 1/3 and 2/3 mentions next real yes moment', () {
      final one = engine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        surface: CapacityReturnTriggerSurface.archiveHome,
      );
      expect(one.title, CapacityReturnTriggerCopy.archiveHomeTitle(1));
      expect(one.body, CapacityReturnTriggerCopy.archiveHomeBody(1, target: 3));

      final two = engine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        surface: CapacityReturnTriggerSurface.archiveHome,
      );
      expect(two.body, CapacityReturnTriggerCopy.archiveHomeBody(2, target: 3));
    });

    test('hides archive home return trigger at 3/3', () {
      final result = engine.buildFromJournal(
        entries: [
          _capacityEntry('real_0'),
          _capacityEntry('real_1'),
          _capacityEntry('real_2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
        surface: CapacityReturnTriggerSurface.archiveHome,
      );
      expect(result.showCard, isFalse);
    });

    test('record line under 3 moments', () {
      final result = engine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 2,
          surface: CapacityReturnTriggerSurface.recordLine,
        ),
      );
      expect(
        CapacityReturnTriggerEngine.recordProgressLine(result),
        CapacityReturnTriggerCopy.recordProgressLine,
      );
    });

    test('record line hidden at 3/3', () {
      final result = engine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 3,
          surface: CapacityReturnTriggerSurface.recordLine,
        ),
      );
      expect(CapacityReturnTriggerEngine.recordProgressLine(result), isEmpty);
    });

    test('beta mission hint for 1-2 moments', () {
      final one = engine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 1,
          surface: CapacityReturnTriggerSurface.betaMissionHint,
        ),
      );
      expect(
        CapacityReturnTriggerEngine.betaMissionHint(one),
        CapacityReturnTriggerCopy.betaMissionHint,
      );

      final three = engine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 3,
          surface: CapacityReturnTriggerSurface.betaMissionHint,
        ),
      );
      expect(CapacityReturnTriggerEngine.betaMissionHint(three), isEmpty);
    });

    test('hidden for sample/demo-only entries', () {
      final result = engine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
        surface: CapacityReturnTriggerSurface.archiveHome,
      );
      expect(result.showCard, isFalse);
    });

    test('hidden in screenshot mode', () {
      final result = engine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: true,
          capacityWedgeActive: true,
          capacityMomentCount: 1,
        ),
      );
      expect(result.showCard, isFalse);
    });

    test('does not store private text', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0', transcript: _privateSnippet)],
        capacityLoopActive: true,
        capacityCohortActive: false,
        surface: CapacityReturnTriggerSurface.completion,
      );
      expect(result.title.toLowerCase(), isNot(contains(_privateSnippet)));
      expect(result.body.toLowerCase(), isNot(contains(_privateSnippet)));
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityReturnTriggerCopy.allVisibleStrings());
    });
  });

  group('CapacityThreeMomentEngine integration', () {
    test('reuses activation card with return copy for 1-2 moments', () {
      final one = threeMomentEngine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(one.title, CapacityReturnTriggerCopy.archiveHomeTitle(1));
      expect(
        one.subtitle,
        CapacityReturnTriggerCopy.archiveHomeBody(1, target: 3),
      );
      expect(one.progressLabel, isEmpty);
      expect(one.showReviewSecondary, isTrue);
      expect(
        one.reviewSecondaryLabel,
        CapacityReturnTriggerCopy.archiveHomeSecondaryCta(1),
      );
      expect(one.showQuickSaveSecondary, isFalse);
    });

    test('at 3/3 review loop CTA and no archive home card', () {
      final three = threeMomentEngine.buildFromJournal(
        entries: [
          _capacityEntry('real_0'),
          _capacityEntry('real_1'),
          _capacityEntry('real_2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(three.primaryCtaLabel, CapacityThreeMomentCopy.reviewLoopCta);
      expect(three.showOnArchiveHome, isFalse);
      expect(three.showReviewSecondary, isFalse);
    });

    test('record progress uses return trigger line under target', () {
      final result = threeMomentEngine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(
        CapacityThreeMomentEngine.recordProgressLine(result),
        CapacityReturnTriggerCopy.recordProgressLine,
      );
    });
  });

  group('CapacityReturnTriggerCard', () {
    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityReturnTriggerCard(
              sampleMode: true,
              result: engine.build(
                const CapacityReturnTriggerInput(
                  sampleMode: false,
                  screenshotMode: false,
                  capacityWedgeActive: true,
                  capacityMomentCount: 1,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('capacity_return_trigger_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('routes secondary to record on completion card', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: CapacityReturnTriggerCard(
                result: engine.build(
                  const CapacityReturnTriggerInput(
                    sampleMode: false,
                    screenshotMode: false,
                    capacityWedgeActive: true,
                    capacityMomentCount: 1,
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) =>
                const Scaffold(body: Text('record screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(
        find.byKey(const Key('capacity_return_trigger_card_secondary_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('record screen'), findsOneWidget);
    });

    testWidgets('primary dismisses completion card', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityReturnTriggerCard(
              result: engine.build(
                const CapacityReturnTriggerInput(
                  sampleMode: false,
                  screenshotMode: false,
                  capacityWedgeActive: true,
                  capacityMomentCount: 1,
                ),
              ),
              onPrimaryDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('capacity_return_trigger_card_primary_button')),
      );
      await tester.pump();

      expect(dismissed, isTrue);
    });
  });

  group('Archive Home card wall', () {
    test('does not add a separate return card section id', () {
      expect(
        ArchiveHomeSectionId.values.map((section) => section.name),
        isNot(contains('capacityReturnTrigger')),
      );
    });

    test('activation card remains single primary capacity card', () {
      const priorityEngine = ArchiveHomePriorityEngine();
      final plan = priorityEngine.build(
        const ArchiveHomePriorityInput(
          savedEntryCount: 1,
          usableEvidenceCount: 1,
          depthLevel: ArchiveDepthLevel.notStarted,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: true,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityThreeMomentActivationVisible: true,
          capacityLoopVisible: false,
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

      final capacityCards = [...plan.primarySections, ...plan.secondarySections]
          .where(
            (section) =>
                section == ArchiveHomeSectionId.capacityThreeMomentActivation ||
                section == ArchiveHomeSectionId.capacityLoop,
          );
      expect(capacityCards.length, lessThanOrEqualTo(2));
    });
  });

  group('Quick capture and record remain available', () {
    test('quick save secondary on 3-moment card at 0/3 only', () {
      final zero = threeMomentEngine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(zero.showQuickSaveSecondary, isTrue);

      final one = threeMomentEngine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(one.showQuickSaveSecondary, isFalse);
      expect(one.quickSaveRoute, LowEffortYesCaptureCopy.route);
      expect(one.primaryRoute, isEmpty);
      expect(one.primaryDismisses, isTrue);
      expect(one.reviewSecondaryRoute, CapacityReturnTriggerCopy.recordRoute);
    });
  });
}