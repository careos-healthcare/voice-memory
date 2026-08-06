import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_return_trigger_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_three_moment_card.dart';

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

CapacityThreeMomentResult _visibleResult({
  int count = 0,
  bool showOnArchiveHome = true,
}) => CapacityThreeMomentResult(
  hasCard: true,
  showOnArchiveHome: showOnArchiveHome,
  showOnRecordProgress: count < 3,
  showOnCapacityLoop: count < 3,
  title: CapacityThreeMomentCopy.cardTitle,
  subtitle: CapacityThreeMomentCopy.cardSubtitle,
  progressLabel: CapacityThreeMomentCopy.progressLabel(count, target: 3),
  emptyBody: count <= 0 ? CapacityThreeMomentCopy.emptyBody : '',
  primaryCtaLabel: count >= 3
      ? CapacityThreeMomentCopy.reviewLoopCta
      : CapacityThreeMomentCopy.saveYesMomentCta,
  primaryRoute: count >= 3
      ? CapacityThreeMomentCopy.loopRoute
      : CapacityThreeMomentCopy.recordRoute,
  primaryDismisses: count >= 1 && count < 3,
  showQuickSaveSecondary: count < 3,
  quickSaveRoute: '/quick-yes-capture',
  showReviewSecondary: count >= 1 && count < 3,
  reviewSecondaryLabel: count == 2 ? 'Save next yes moment' : 'Save another',
  reviewSecondaryRoute: '/record',
  capacityMomentCount: count,
  activationTarget: 3,
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
    expect(lower, isNot(contains('burnout')));
    expect(lower, isNot(contains(_privateSnippet)));
  }
}

ArchiveHomePriorityInput _priorityInput({
  int savedEntryCount = 0,
  bool capacityThreeMomentActivationVisible = false,
  bool capacityLoopVisible = false,
  bool capacityPullReasonVisible = false,
}) => ArchiveHomePriorityInput(
  savedEntryCount: savedEntryCount,
  usableEvidenceCount: savedEntryCount,
  depthLevel: ArchiveDepthLevel.notStarted,
  returnChangesAvailable: false,
  weeklyReviewAvailable: false,
  sampleMode: false,
  proPreviewPromoVisible: false,
  showEmptySample: savedEntryCount == 0,
  firstWeekPathVisible: savedEntryCount < 7,
  dailyArchiveExerciseVisible: true,
  archiveClarityProgressVisible: true,
  capacityThreeMomentActivationVisible: capacityThreeMomentActivationVisible,
  capacityLoopVisible: capacityLoopVisible,
  capacityPullReasonVisible: capacityPullReasonVisible,
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
);

void main() {
  const engine = CapacityThreeMomentEngine();

  group('CapacityThreeMomentEngine', () {
    test('hidden for generic users without capacity evidence', () {
      final result = engine.buildFromJournal(
        entries: const [],
        capacityLoopActive: false,
        capacityCohortActive: false,
      );
      expect(result.hasCard, isFalse);
    });

    test('visible for capacity-yes users with 0 real moments', () {
      final result = engine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(result.hasCard, isTrue);
      expect(result.showOnArchiveHome, isTrue);
      expect(result.progressLabel, '0 of 3 yes moments saved');
      expect(result.emptyBody, CapacityThreeMomentCopy.emptyBody);
    });

    test('excludes sample/demo entries', () {
      final result = engine.buildFromJournal(
        entries: SampleArchiveEntries.build(),
        capacityLoopActive: true,
        capacityCohortActive: true,
      );
      expect(result.hasCard, isFalse);
    });

    test('hidden in ScreenshotMode', () {
      final result = engine.build(
        const CapacityThreeMomentInput(
          sampleMode: true,
          capacityWedgeActive: true,
          capacityEvidenceCount: 0,
          capacityMomentCount: 0,
        ),
      );
      expect(result.hasCard, isFalse);
    });

    test('shows 0/3 progress and return copy for 1/3 and 2/3', () {
      final zero = engine.buildFromJournal(
        entries: const [],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(zero.progressLabel, '0 of 3 yes moments saved');

      final one = engine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(one.title, 'First moment saved.');
      expect(
        one.subtitle,
        CapacityReturnTriggerCopy.archiveHomeBody(1, target: 3),
      );
      expect(one.progressLabel, isEmpty);
      expect(one.showReviewSecondary, isTrue);
      expect(one.showQuickSaveSecondary, isFalse);

      final two = engine.buildFromJournal(
        entries: [_capacityEntry('real_0'), _capacityEntry('real_1')],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(
        two.subtitle,
        CapacityReturnTriggerCopy.archiveHomeBody(2, target: 3),
      );
      expect(two.progressLabel, isEmpty);
      expect(two.showQuickSaveSecondary, isFalse);
    });

    test('switches CTA to review loop at 3/3', () {
      final result = engine.buildFromJournal(
        entries: [
          _capacityEntry('real_0'),
          _capacityEntry('real_1'),
          _capacityEntry('real_2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(result.primaryCtaLabel, CapacityThreeMomentCopy.reviewLoopCta);
      expect(result.primaryRoute, CapacityThreeMomentCopy.loopRoute);
      expect(
        result.progressLabel,
        '3 of 3 yes moments saved — review your yes loop',
      );
      expect(result.showOnArchiveHome, isFalse);
    });

    test('record progress line only for wedge users under target', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(
        CapacityThreeMomentEngine.recordProgressLine(result),
        'Use this when a real yes moment happens again.',
      );
    });

    test('does not store private text', () {
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('real_0', transcript: _privateSnippet)],
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(result.title.toLowerCase(), isNot(contains(_privateSnippet)));
      expect(result.subtitle.toLowerCase(), isNot(contains(_privateSnippet)));
      expect(
        result.progressLabel.toLowerCase(),
        isNot(contains(_privateSnippet)),
      );
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityThreeMomentCopy.allVisibleStrings());
    });
  });

  group('CapacityThreeMomentCard', () {
    testWidgets('hidden in sample mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityThreeMomentCard(
              result: _visibleResult(),
              sampleMode: true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('capacity_three_moment_card_hidden')),
        findsOneWidget,
      );
    });

    testWidgets('secondary routes to Record when under 3 at 1/3', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: CapacityThreeMomentCard(result: _visibleResult(count: 1)),
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
        find.byKey(const Key('capacity_three_moment_card_review_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('record screen'), findsOneWidget);
    });

    testWidgets('routes to Capacity Loop when 3+', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: CapacityThreeMomentCard(
                result: _visibleResult(count: 3, showOnArchiveHome: true),
              ),
            ),
          ),
          GoRoute(
            path: '/capacity-loop',
            builder: (context, state) =>
                const Scaffold(body: Text('capacity loop screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(
        find.byKey(const Key('capacity_three_moment_card_primary_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('capacity loop screen'), findsOneWidget);
    });

    testWidgets('does not expose transcript text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityThreeMomentCard(result: _visibleResult(count: 1)),
          ),
        ),
      );

      expect(find.textContaining(_privateSnippet), findsNothing);
    });
  });

  group('Archive Home priority', () {
    const priorityEngine = ArchiveHomePriorityEngine();

    test('activation precedes pull reason in sticky loop order', () {
      final ranked = [
        ...priorityEngine
            .build(
              _priorityInput(
                savedEntryCount: 1,
                capacityThreeMomentActivationVisible: true,
                capacityPullReasonVisible: true,
              ),
            )
            .primarySections,
        ...priorityEngine
            .build(
              _priorityInput(
                savedEntryCount: 1,
                capacityThreeMomentActivationVisible: true,
                capacityPullReasonVisible: true,
              ),
            )
            .secondarySections,
      ];

      expect(
        ranked,
        contains(ArchiveHomeSectionId.capacityThreeMomentActivation),
      );
      expect(ranked, contains(ArchiveHomeSectionId.capacityPullReason));
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityThreeMomentActivation),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.capacityPullReason)),
      );
    });

    test('respects primary card cap', () {
      final plan = priorityEngine.build(
        _priorityInput(
          savedEntryCount: 1,
          capacityThreeMomentActivationVisible: true,
          capacityLoopVisible: true,
          capacityPullReasonVisible: true,
        ),
      );
      expect(plan.primarySections.length, lessThanOrEqualTo(4));
    });
  });
}
