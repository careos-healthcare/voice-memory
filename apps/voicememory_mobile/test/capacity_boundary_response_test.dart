import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_store.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_boundary_response_card.dart';

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

JournalEntry _capacityEntry(String id) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript:
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

CapacityBoundaryResponseInput _eligibleInput({
  CapacityBoundaryResponseSelection? selection,
  bool pendingPullReason = false,
  bool pendingDecisionOutcome = false,
  bool pendingCostCheckin = false,
  bool beforeYesPauseOnHome = false,
  bool weeklyReviewOnHome = false,
}) =>
    CapacityBoundaryResponseInput(
      sampleMode: false,
      realSavedMomentCount: 3,
      capacityWedgeActive: true,
      capacityMomentCount: 3,
      capacityEvidenceCount: 3,
      outcomeOrCostRecordCount: 2,
      pendingPullReasonOnHome: pendingPullReason,
      pendingDecisionOutcome: pendingDecisionOutcome,
      pendingCostCheckin: pendingCostCheckin,
      beforeYesPauseOnHome: beforeYesPauseOnHome,
      weeklyReviewOnHome: weeklyReviewOnHome,
      selection: selection,
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

Future<void> _resetStore(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_capacity_boundary_journal_$stamp.json',
    prefsPath: '/tmp/vm_capacity_boundary_prefs_$stamp.json',
  );
  CapacityBoundaryResponseStore.resetForTest();
}

void main() {
  const engine = CapacityBoundaryResponseEngine();

  setUp(() {
    CapacityBoundaryResponseStore.resetForTest();
  });

  group('CapacityBoundaryResponseEngine', () {
    test('hidden with no evidence', () {
      final result = engine.build(
        const CapacityBoundaryResponseInput(
          sampleMode: false,
          realSavedMomentCount: 0,
          capacityWedgeActive: true,
          capacityMomentCount: 0,
          capacityEvidenceCount: 0,
          outcomeOrCostRecordCount: 0,
          pendingPullReasonOnHome: false,
          pendingDecisionOutcome: false,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
          weeklyReviewOnHome: false,
        ),
      );
      expect(result.hasFeature, isFalse);
    });

    test('hidden for sample/demo-only entries', () {
      final sampleOnly = SampleArchiveEntries.build();
      final result = engine.buildFromJournal(
        entries: sampleOnly,
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(result.hasFeature, isFalse);
    });

    test('appears with enough capacity evidence', () {
      final result = engine.build(_eligibleInput());
      expect(result.hasFeature, isTrue);
      expect(result.title, CapacityBoundaryResponseCopy.title);
    });

    test('appears with enough decision/cost records', () {
      final result = engine.build(
        _eligibleInput().copyWith(
          capacityMomentCount: 1,
          capacityEvidenceCount: 2,
          outcomeOrCostRecordCount: 2,
        ),
      );
      expect(result.hasFeature, isTrue);
    });

    test('shows selected response from templates', () {
      final selection = CapacityBoundaryResponseSelection(
        responseId: CapacityBoundaryResponseIds.checkCapacityComeBack,
        selectedAt: DateTime(2026, 6, 12),
      );
      final result = engine.build(_eligibleInput(selection: selection));
      expect(
        result.selectedResponseText,
        CapacityBoundaryResponseCopy.textForId(
          CapacityBoundaryResponseIds.checkCapacityComeBack,
        ),
      );
      expect(
        CapacityBoundaryResponseIds.all,
        contains(result.selectedResponseId),
      );
    });

    test('does not expose transcript text', () {
      final entries = List.generate(3, (i) => _capacityEntry('e$i'));
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      _expectNoBannedCopy([
        result.title,
        result.subtitle,
        result.body,
        result.cardSummary,
        ...result.templates.map((template) => template.text),
      ]);
    });

    test('archive home suppresses when pending pull reason/outcome/cost/weekly review', () {
      expect(
        CapacityBoundaryResponseEngine.showOnArchiveHome(
          hasFeature: true,
          sampleMode: false,
          pendingPullReason: true,
          pendingDecisionOutcome: false,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
          weeklyReviewOnHome: false,
        ),
        isFalse,
      );
      expect(
        CapacityBoundaryResponseEngine.showOnArchiveHome(
          hasFeature: true,
          sampleMode: false,
          pendingPullReason: false,
          pendingDecisionOutcome: true,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
          weeklyReviewOnHome: false,
        ),
        isFalse,
      );
      expect(
        CapacityBoundaryResponseEngine.showOnArchiveHome(
          hasFeature: true,
          sampleMode: false,
          pendingPullReason: false,
          pendingDecisionOutcome: false,
          pendingCostCheckin: true,
          beforeYesPauseOnHome: false,
          weeklyReviewOnHome: false,
        ),
        isFalse,
      );
      expect(
        CapacityBoundaryResponseEngine.showOnArchiveHome(
          hasFeature: true,
          sampleMode: false,
          pendingPullReason: false,
          pendingDecisionOutcome: false,
          pendingCostCheckin: false,
          beforeYesPauseOnHome: false,
          weeklyReviewOnHome: true,
        ),
        isFalse,
      );
      expect(
        engine.build(
          _eligibleInput(
            pendingDecisionOutcome: false,
            pendingCostCheckin: false,
            weeklyReviewOnHome: false,
          ),
        ).showOnArchiveHome,
        isTrue,
      );
    });

    test('copy passes language guard', () {
      _expectNoBannedCopy(CapacityBoundaryResponseCopy.allVisibleStrings());
    });
  });

  group('CapacityBoundaryResponseStore', () {
    test('stores selected response locally', () async {
      await _resetStore('save');
      await CapacityBoundaryResponseStore.instance().saveSelection(
        CapacityBoundaryResponseIds.needPauseBeforeYes,
      );
      expect(
        CapacityBoundaryResponseStore.cached?.responseId,
        CapacityBoundaryResponseIds.needPauseBeforeYes,
      );
    });

    test('selected response id persists in prefs shape', () {
      final selection = CapacityBoundaryResponseSelection(
        responseId: CapacityBoundaryResponseIds.checkCommitmentsFirst,
        selectedAt: DateTime(2026, 6, 12),
      );
      final restored = CapacityBoundaryResponseSelection.fromJson(
        selection.toJson(),
      );
      expect(restored?.responseId, selection.responseId);
      expect(restored?.selectedAt, selection.selectedAt);
    });

    test('response text is one of safe templates', () {
      for (final id in CapacityBoundaryResponseIds.all) {
        final text = CapacityBoundaryResponseCopy.textForId(id);
        expect(text, isNotNull);
        expect(
          CapacityBoundaryResponseCopy.templates
              .map((template) => template.text),
          contains(text),
        );
      }
    });
  });

  group('CapacityBoundaryResponseCard widget', () {
    testWidgets('renders boundary card', (tester) async {
      final result = engine.build(_eligibleInput());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityBoundaryResponseCard.test(result: result),
          ),
        ),
      );
      expect(find.byKey(const Key('capacity_boundary_response_card')), findsOneWidget);
      expect(find.text(CapacityBoundaryResponseCopy.title), findsOneWidget);
      expect(find.text(CapacityBoundaryResponseCopy.chooseResponseCta), findsOneWidget);
    });

    testWidgets('hidden in sample mode', (tester) async {
      final result = engine.build(_eligibleInput());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityBoundaryResponseCard.test(
              result: result,
              sampleMode: true,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const Key('capacity_boundary_response_card_hidden')),
        findsOneWidget,
      );
    });
  });

  group('CapacityBoundaryResponsePicker copy action', () {
    testWidgets('copy action does not include private transcript text',
        (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      CapacityBoundaryResponseStore.seedForTest(
        CapacityBoundaryResponseSelection(
          responseId: CapacityBoundaryResponseIds.checkCapacityComeBack,
          selectedAt: DateTime.utc(2026, 6, 12),
        ),
      );

      final result = engine.build(
        _eligibleInput(
          selection: CapacityBoundaryResponseStore.cached,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityBoundaryResponsePicker(result: result),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('capacity_boundary_response_copy_button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('capacity_boundary_response_copy_button')),
      );
      await tester.pump();

      final copyCall = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      final copied = (copyCall.arguments as Map)['text'] as String;
      expect(copied, CapacityBoundaryResponseCopy.templates.first.text);
      expect(copied.toLowerCase(), isNot(contains(_privateSnippet)));
      _expectNoBannedCopy([copied]);
    });
  });

  group('Archive Home priority', () {
    test('boundary response ranks after weekly review', () {
      const priorityEngine = ArchiveHomePriorityEngine();
      final plan = priorityEngine.build(
        ArchiveHomePriorityInput(
          savedEntryCount: 4,
          usableEvidenceCount: 4,
          depthLevel: ArchiveDepthLevel.notStarted,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: false,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityLoopVisible: true,
          capacityThreeMomentActivationVisible: false,
          capacityPullReasonVisible: false,
          capacityDecisionOutcomeVisible: false,
          capacityCostLaterCheckinVisible: false,
          capacityActivationFitVisible: false,
          beforeYouSayYesPauseVisible: false,
          capacityWeeklyReviewVisible: true,
          capacityBoundaryResponseVisible: true,
          thenVsNowVisible: false,
          archiveCalendarVisible: false,
          reviewRitualVisible: false,
          milestoneShareVisible: false,
        ),
      );
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(ranked, contains(ArchiveHomeSectionId.capacityBoundaryResponse));
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityWeeklyReview),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.capacityBoundaryResponse)),
      );
    });
  });

  group('Routing', () {
    test('route registered in app router', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/capacity-boundary-response'"));
    });

    test('sensitive route guard includes capacity boundary response', () {
      expect(
        SensitiveRoutes.isSensitiveRoute('/capacity-boundary-response'),
        isTrue,
      );
    });
  });
}
