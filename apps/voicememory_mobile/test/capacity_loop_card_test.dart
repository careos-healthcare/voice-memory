import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_gates.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_models.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_mode.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capacity_loop_card.dart';
import 'package:voicememory_mobile/widgets/record/capacity_yes_record_prompt_card.dart';

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
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(
  String id, {
  String? transcript,
  List<String> themes = const ['work'],
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 12),
  transcript:
      transcript ??
      'I $_privateSnippet again even when I was tired today and said yes.',
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: themes,
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _realCapacityEntries(int count) => List.generate(
  count,
  (i) => _capacityEntry(
    'real_$i',
    transcript:
        'I said yes again under pressure even though I had no capacity left today number $i.',
  ),
);

CapacityLoopInput _input({
  int realSavedMomentCount = 0,
  int capacityEvidenceCount = 0,
  bool capacityLoopActive = false,
  bool capacityCohortActive = false,
  bool sampleMode = false,
  String? topRecurringTheme,
  int costSignalCount = 0,
}) => CapacityLoopInput(
  realSavedMomentCount: realSavedMomentCount,
  capacityEvidenceCount: capacityEvidenceCount,
  capacityLoopActive: capacityLoopActive,
  capacityCohortActive: capacityCohortActive,
  sampleMode: sampleMode,
  topRecurringTheme: topRecurringTheme,
  costSignalCount: costSignalCount,
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
    expect(lower, isNot(contains('archiveme knows')));
  }
}

CapacityLoopResult _fullResult({int count = 3}) => CapacityLoopResult(
  hasCard: true,
  isEmpty: false,
  showOnArchiveHome: true,
  title: CapacityLoopCopy.title,
  subtitle: CapacityLoopCopy.subtitle,
  evidenceCountLabel: CapacityLoopCopy.evidenceCountLabel(count),
  whatRepeated: CapacityLoopCopy.whatRepeatedStrong,
  costLater: CapacityLoopCopy.costLaterWithCount(2),
  watchNext: CapacityLoopCopy.watchNext,
  primaryCtaLabel: CapacityLoopCopy.saveYesMomentCta,
  secondaryCtaLabel: CapacityLoopCopy.reviewLoopCta,
  primaryRoute: CapacityLoopCopy.recordRoute,
  secondaryRoute: CapacityLoopCopy.route,
  shareCopy: CapacityLoopCopy.shareCopy,
  triggerLabel: CapacityLoopCopy.loopDiagramTrigger,
  saidYesLabel: CapacityLoopCopy.loopDiagramSaidYes,
  costLaterLabel: CapacityLoopCopy.loopDiagramCostLater,
  repeatedLabel: CapacityLoopCopy.loopDiagramRepeated,
  watchNextLabel: CapacityLoopCopy.loopDiagramWatchNext,
  costEvidenceLabel: '',
);

void main() {
  const engine = CapacityLoopEngine();

  group('CapacityLoopEngine', () {
    test('hidden with 0 real entries', () {
      final result = engine.build(_input());
      expect(result.hasCard, isFalse);
      expect(result.showOnArchiveHome, isFalse);
    });

    test('hidden for sample/demo-only entries', () {
      final samples = SampleArchiveEntries.build();
      final result = engine.buildFromJournal(
        entries: samples,
        capacityLoopActive: true,
        capacityCohortActive: true,
      );
      expect(result.hasCard, isFalse);
      expect(engine.realSavedMomentCount(samples), 0);
    });

    test('appears after enough capacity-yes evidence', () {
      final entries = _realCapacityEntries(3);
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: false,
      );
      expect(result.hasCard, isTrue);
      expect(result.showOnArchiveHome, isTrue);
      expect(result.title, 'Your yes loop');
    });

    test('does not expose private transcript text', () {
      final entries = _realCapacityEntries(3);
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: true,
        capacityCohortActive: true,
      );
      final visible = [
        result.title,
        result.subtitle,
        result.evidenceCountLabel,
        result.whatRepeated,
        result.costLater,
        result.watchNext,
        result.primaryCtaLabel,
        result.secondaryCtaLabel,
        result.shareCopy,
      ].join(' ');
      expect(visible.toLowerCase(), isNot(contains(_privateSnippet)));
      expect(visible, isNot(contains('transcript')));
    });

    test('uses cautious language', () {
      final result = engine.build(
        _input(
          realSavedMomentCount: 3,
          capacityEvidenceCount: 3,
          capacityLoopActive: true,
          costSignalCount: 2,
        ),
      );
      expect(
        result.whatRepeated.toLowerCase(),
        anyOf(
          contains('may'),
          contains('starting to show'),
          contains('forming'),
          contains('saved moments where'),
        ),
      );
    });

    test('includes Built from 3 saved moments when applicable', () {
      final result = engine.build(
        _input(
          realSavedMomentCount: 3,
          capacityEvidenceCount: 3,
          capacityLoopActive: true,
        ),
      );
      expect(result.evidenceCountLabel, 'Built from 3 saved moments');
    });

    test('generic users do not see card too early', () {
      final entries = List.generate(
        3,
        (i) => _capacityEntry(
          'generic_$i',
          transcript:
              'I noticed I kept switching tasks at work today without deciding the next step.',
          themes: const ['decisions'],
        ),
      );
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: false,
        capacityCohortActive: false,
      );
      expect(result.hasCard, isFalse);
    });

    test('generic users see card with enough capacity evidence', () {
      final entries = _realCapacityEntries(3);
      final result = engine.buildFromJournal(
        entries: entries,
        capacityLoopActive: false,
        capacityCohortActive: false,
      );
      expect(engine.countCapacityEvidence(entries), greaterThanOrEqualTo(2));
      final withEvidence = engine.build(
        _input(
          realSavedMomentCount: 3,
          capacityEvidenceCount: engine.countCapacityEvidence(entries),
          capacityLoopActive: false,
          capacityCohortActive: false,
        ),
      );
      expect(withEvidence.hasCard, isTrue);
    });

    test('ScreenshotMode hides live card', () {
      final result = engine.build(_input(sampleMode: true));
      expect(result.showOnArchiveHome, isFalse);
    });

    test('no banned copy in capacity loop strings', () {
      _expectNoBannedCopy([
        CapacityLoopCopy.title,
        CapacityLoopCopy.subtitle,
        CapacityLoopCopy.emptyStateBody,
        CapacityLoopCopy.formingWhatRepeated,
        CapacityLoopCopy.whatRepeatedStrong,
        CapacityLoopCopy.watchNext,
        CapacityLoopCopy.saveYesMomentCta,
        CapacityLoopCopy.saveYesMomentShortCta,
        CapacityLoopCopy.reviewLoopCta,
        CapacityLoopCopy.shareCopy,
        CapacityLoopCopy.recordPromptTitle,
        CapacityLoopCopy.recordPromptBody,
      ]);
    });
  });

  group('CapacityLoopCard widget', () {
    testWidgets('renders card with required copy', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityLoopCard.test(
              entries: _realCapacityEntries(3),
              result: _fullResult(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('capacity_loop_card')), findsOneWidget);
      expect(find.text('Your yes loop'), findsOneWidget);
      expect(find.text('Save yes moment'), findsOneWidget);
      expect(find.text('Built from 3 saved moments'), findsOneWidget);
    });

    testWidgets('hidden in screenshot mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityLoopCard.test(
              entries: _realCapacityEntries(3),
              result: _fullResult(),
              sampleMode: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('capacity_loop_card_hidden')),
        findsOneWidget,
      );
      expect(find.text('Your yes loop'), findsNothing);
    });

    testWidgets('does not render private transcript text', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityLoopCard.test(
              entries: _realCapacityEntries(3),
              result: _fullResult(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining(_privateSnippet), findsNothing);
    });
  });

  group('CapacityYesRecordPromptCard', () {
    testWidgets('capacity-yes cohort gets capacity prompt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CapacityYesRecordPromptCard(onSaveMoment: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('About to say yes?'), findsOneWidget);
      expect(find.text('Save the moment first.'), findsOneWidget);
      expect(find.text('Save yes moment'), findsOneWidget);
    });
  });

  group('CapacityLoopGates', () {
    test('record prompt only for capacity wedge', () {
      expect(
        CapacityLoopGates.showRecordPrompt(
          capacityWedgeActive: true,
          sampleMode: false,
        ),
        isTrue,
      );
      expect(
        CapacityLoopGates.showRecordPrompt(
          capacityWedgeActive: false,
          sampleMode: false,
        ),
        isFalse,
      );
    });
  });

  group('Archive Home priority', () {
    test('capacity loop ranks high when visible', () {
      const priorityEngine = ArchiveHomePriorityEngine();
      final plan = priorityEngine.build(
        ArchiveHomePriorityInput(
          savedEntryCount: 3,
          usableEvidenceCount: 3,
          depthLevel: ArchiveDepthLevel.notStarted,
          returnChangesAvailable: false,
          weeklyReviewAvailable: false,
          sampleMode: false,
          proPreviewPromoVisible: false,
          showEmptySample: false,
          firstWeekPathVisible: true,
          dailyArchiveExerciseVisible: true,
          archiveClarityProgressVisible: true,
          capacityLoopVisible: true,
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
      final ranked = [...plan.primarySections, ...plan.secondarySections];
      expect(ranked, contains(ArchiveHomeSectionId.capacityLoop));
      expect(
        ranked.indexOf(ArchiveHomeSectionId.capacityLoop),
        lessThan(ranked.indexOf(ArchiveHomeSectionId.archiveClarityProgress)),
      );
    });
  });

  group('Routing and privacy', () {
    test('route registered in app router', () {
      final router = File('lib/router/app_router.dart').readAsStringSync();
      expect(router, contains("path: '/capacity-loop'"));
    });

    test('sensitive route guard includes capacity loop', () {
      expect(SensitiveRoutes.isSensitiveRoute('/capacity-loop'), isTrue);
    });

    test('share copy is fixed safe text only', () {
      expect(CapacityLoopCopy.shareCopy, contains('No private entries shared'));
      expect(
        CapacityLoopCopy.shareCopy.toLowerCase(),
        isNot(contains('transcript')),
      );
    });
  });
}
