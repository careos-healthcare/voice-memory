import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/belief_change/belief_change_moment_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/pattern_confidence/pattern_confidence_analytics.dart';
import 'package:voicememory_mobile/features/pattern_confidence/pattern_confidence_copy.dart';
import 'package:voicememory_mobile/features/pattern_confidence/pattern_confidence_engine.dart';
import 'package:voicememory_mobile/features/pattern_confidence/pattern_confidence_model.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_model.dart';
import 'package:voicememory_mobile/features/what_changed/what_changed_v2_store.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_confidence_card.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? _now,
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
  syncStatus: SyncStatus.localOnly,
);

List<JournalEntry> _twoRelatedRepeatEntries() => [
  _entry(
    id: 'e1',
    transcript: _strongRepeat,
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
];

List<JournalEntry> _threeRelatedRepeatEntries({DateTime? anchor}) {
  final base = anchor ?? _now;
  return [
    _entry(
      id: 'e1',
      transcript: _strongRepeat,
      createdAt: base.subtract(const Duration(days: 2)),
    ),
    _entry(
      id: 'e2',
      transcript:
          'Same thing — said yes when I had no capacity for one more thing.',
      createdAt: base.subtract(const Duration(days: 1)),
    ),
    _entry(
      id: 'e3',
      transcript:
          'I said yes again even though I had no capacity for one more ask.',
      createdAt: base,
    ),
  ];
}

List<JournalEntry> _fourRelatedRepeatEntries() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'The meeting invite came in and I said yes again with no capacity left for it.',
    createdAt: _now.add(const Duration(days: 1)),
  ),
];

List<JournalEntry> _fourWithDifferentLatestPhrase() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'e4',
    transcript:
        'I checked my calendar before answering when they asked me to take on more work.',
    createdAt: _now.add(const Duration(days: 1)),
  ),
];

List<JournalEntry> _staleRepeatEntries() => [
  _entry(
    id: 'e1',
    transcript: _strongRepeat,
    createdAt: DateTime(2026, 5, 1, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 5, 3, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 5, 5, 12),
  ),
];

RepeatReturnCheckRecord _answeredRecord({
  required String entryId,
  required RepeatReturnCheckChoice choice,
}) => RepeatReturnCheckRecord(
  entryId: entryId,
  choice: choice,
  entryCountAtCapture: 4,
  createdAt: DateTime(2026, 6, 13),
);

PatternConfidenceExplanationResult _explanationFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  List<RepeatReturnCheckRecord> returnChecks = const [],
  DateTime? now,
}) {
  final built = PatternConfidenceEngine.buildExplanation(
    entries: entries,
    beliefSurfaceVisible: beliefSurfaceVisible,
    source: 'test',
    returnChecks: returnChecks,
    viewingConfirmedRepeatOrTimeline: true,
    now: now ?? _now,
  );
  expect(built, isNotNull);
  return built!;
}

PatternConfidenceExplanationResult _manualExplanation(
  PatternConfidenceExplanationState state,
) => PatternConfidenceExplanationResult(
  shouldShow: true,
  entryCount: 3,
  source: 'test',
  hasConfirmedRepeat: true,
  hasBeliefSurface: true,
  confidenceState: state,
  title: PatternConfidenceCopy.explanationTitle,
  intro: PatternConfidenceCopy.explanationIntro,
  label: PatternConfidenceCopy.explanationLabelFor(state),
  body: PatternConfidenceCopy.explanationBodyFor(state),
  footer: PatternConfidenceCopy.explanationFooter,
  differentiationLine: PatternConfidenceCopy.explanationDifferentiation,
);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    await WhatChangedV2Store.resetForTest();
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    PatternConfidenceAnalytics.resetForTest();
    PatternConfidenceAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(PatternConfidenceAnalytics.resetForTest);

  group('PatternConfidenceEngine badge labels', () {
    test('two related moments show Early signal', () {
      final confidence = PatternConfidenceEngine.build(
        entries: _twoRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.earlySignal);
      expect(confidence.label, PatternConfidenceCopy.earlySignalLabel);
      expect(confidence.body, PatternConfidenceCopy.earlySignalBody);
    });

    test('three related moments show Repeated pattern', () {
      final confidence = PatternConfidenceEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.repeatedPattern);
      expect(confidence.label, PatternConfidenceCopy.repeatedPatternLabel);
    });

    test('later change evidence shows Changing pattern', () {
      final confidence = PatternConfidenceEngine.build(
        entries: _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.changingPattern);
      expect(confidence.label, PatternConfidenceCopy.changingPatternLabel);
    });

    test('softer answer shows Softening pattern', () async {
      final entries = _fourRelatedRepeatEntries();
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );

      final confidence = PatternConfidenceEngine.build(
        entries: entries,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.softeningPattern);
      expect(confidence.label, PatternConfidenceCopy.softeningPatternLabel);
    });

    test('generic test entries show Not enough yet', () {
      final confidence = PatternConfidenceEngine.build(
        entries: [
          _entry(id: 'g1', transcript: 'This is a test to check function'),
          _entry(id: 'g2', transcript: 'This is a second test for pressure'),
        ],
      );
      expect(confidence, isNotNull);
      expect(confidence!.state, PatternConfidenceState.notEnoughYet);
      expect(confidence.label, PatternConfidenceCopy.notEnoughYetLabel);
    });

    test('unrelated entries hide safely when not enough yet is suppressed', () {
      final confidence = PatternConfidenceEngine.build(
        entries: [
          _entry(id: 'a', transcript: 'A quiet lunch with a friend today.'),
          _entry(id: 'b', transcript: 'Another unrelated note about errands.'),
        ],
        hideNotEnoughYet: true,
      );
      expect(confidence, isNull);
    });
  });

  group('PatternConfidenceEngine explanation states', () {
    test('early signal resolves from two related moments', () {
      final result = _explanationFor(_twoRelatedRepeatEntries());
      expect(
        result.confidenceState,
        PatternConfidenceExplanationState.earlySignal,
      );
      expect(result.label, PatternConfidenceCopy.explanationEarlySignalLabel);
      expect(result.body, PatternConfidenceCopy.explanationEarlySignalBody);
    });

    test('repeated resolves when repeat evidence spans saved moments', () {
      final result = _manualExplanation(
        PatternConfidenceExplanationState.repeated,
      );
      expect(result.label, PatternConfidenceCopy.explanationRepeatedLabel);
      expect(result.body, PatternConfidenceCopy.explanationRepeatedBody);
    });

    test('current resolves from recent repeat evidence', () {
      final result = _explanationFor(_threeRelatedRepeatEntries());
      expect(result.confidenceState, PatternConfidenceExplanationState.current);
      expect(result.label, PatternConfidenceCopy.explanationCurrentLabel);
      expect(result.body, PatternConfidenceCopy.explanationCurrentBody);
    });

    test('fading resolves when repeat evidence is not recent', () {
      final result = _manualExplanation(
        PatternConfidenceExplanationState.fading,
      );
      expect(result.confidenceState, PatternConfidenceExplanationState.fading);
      expect(result.label, PatternConfidenceCopy.explanationFadingLabel);
      expect(result.body, PatternConfidenceCopy.explanationFadingBody);
    });

    test('needs fresh proof resolves from stale repeat evidence', () {
      final result = _explanationFor(_staleRepeatEntries());
      expect(
        result.confidenceState,
        PatternConfidenceExplanationState.needsFreshProof,
      );
      expect(
        result.label,
        PatternConfidenceCopy.explanationNeedsFreshProofLabel,
      );
      expect(result.body, PatternConfidenceCopy.explanationNeedsFreshProofBody);
    });

    test('softened resolves from softer return evidence', () async {
      final entries = _fourRelatedRepeatEntries();
      await WhatChangedV2Store.instance().saveSelection(
        entryId: 'e4',
        option: WhatChangedV2Option.softer,
        entryCountAtCapture: 4,
      );

      final result = _explanationFor(entries);
      expect(
        result.confidenceState,
        PatternConfidenceExplanationState.softened,
      );
      expect(result.label, PatternConfidenceCopy.explanationSoftenedLabel);
      expect(result.body, PatternConfidenceCopy.explanationSoftenedBody);
    });

    test('changed resolves from changing return evidence', () {
      final result = _explanationFor(
        _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
      );
      expect(result.confidenceState, PatternConfidenceExplanationState.changed);
      expect(result.label, PatternConfidenceCopy.explanationChangedLabel);
      expect(result.body, PatternConfidenceCopy.explanationChangedBody);
    });

    test('hidden when not enough evidence', () {
      expect(
        PatternConfidenceEngine.buildExplanation(
          entries: [
            _entry(id: 'g1', transcript: 'This is a test to check function'),
            _entry(id: 'g2', transcript: 'This is a second test for pressure'),
          ],
          beliefSurfaceVisible: false,
          source: 'test',
        ),
        isNull,
      );
    });

    test('hidden during degraded transcript state on record', () {
      final result = _explanationFor(_threeRelatedRepeatEntries());
      expect(
        PatternConfidenceEngine.shouldShowExplanationOnRecordReady(
          result: result,
          isDegradedTranscriptState: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          otherEducationCardCount: 0,
        ),
        isFalse,
      );
    });

    test('hidden during post-save degraded state', () {
      final result = _explanationFor(_threeRelatedRepeatEntries());
      expect(
        PatternConfidenceEngine.shouldShowExplanation(
          result: result,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: true,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          otherEducationCardCount: 0,
        ),
        isFalse,
      );
    });

    test('hidden during active What Changed', () {
      final result = _explanationFor(_threeRelatedRepeatEntries());
      expect(
        PatternConfidenceEngine.shouldShowExplanationOnPatterns(
          result: result,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('record compact hidden when another education card is active', () {
      final result = _explanationFor(_threeRelatedRepeatEntries());
      expect(
        PatternConfidenceEngine.shouldShowExplanationOnRecordReady(
          result: result,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          otherEducationCardCount: 1,
        ),
        isFalse,
      );
    });

    test('weekly compact shown when primary patterns placement is hidden', () {
      final result = _explanationFor(_threeRelatedRepeatEntries());
      expect(
        PatternConfidenceEngine.shouldShowExplanationOnWeeklyReview(
          result: result,
          primaryPlacementVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });
  });

  group('PatternConfidenceCard', () {
    Future<void> _pumpCard(
      WidgetTester tester,
      PatternConfidenceExplanationResult result, {
      bool compact = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatternConfidenceCard.test(
              result: result,
              source: 'test',
              compact: compact,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders "Why ArchiveMe is showing this"', (tester) async {
      await _pumpCard(tester, _explanationFor(_threeRelatedRepeatEntries()));

      expect(find.byKey(const Key('pattern_confidence_card')), findsOneWidget);
      expect(find.text(PatternConfidenceCopy.explanationTitle), findsOneWidget);
    });

    testWidgets('renders "saved evidence, not a single answer"', (
      tester,
    ) async {
      await _pumpCard(tester, _explanationFor(_threeRelatedRepeatEntries()));

      expect(
        find.textContaining('saved evidence, not a single answer'),
        findsOneWidget,
      );
    });

    testWidgets('early signal says clue not conclusion', (tester) async {
      await _pumpCard(tester, _explanationFor(_twoRelatedRepeatEntries()));

      expect(find.textContaining('clue, not a conclusion'), findsOneWidget);
    });

    testWidgets('repeated says returned across saved moments', (tester) async {
      await _pumpCard(
        tester,
        _manualExplanation(PatternConfidenceExplanationState.repeated),
      );

      expect(
        find.textContaining('returned across saved moments'),
        findsOneWidget,
      );
    });

    testWidgets('current says appeared recently', (tester) async {
      await _pumpCard(tester, _explanationFor(_threeRelatedRepeatEntries()));

      expect(find.textContaining('appeared recently'), findsOneWidget);
    });

    testWidgets('fading says less weight', (tester) async {
      await _pumpCard(
        tester,
        _manualExplanation(PatternConfidenceExplanationState.fading),
      );

      expect(find.textContaining('less weight'), findsOneWidget);
    });

    testWidgets('softened says less force or urgency', (tester) async {
      await _pumpCard(
        tester,
        _manualExplanation(PatternConfidenceExplanationState.softened),
      );

      expect(find.textContaining('less force or urgency'), findsOneWidget);
    });

    testWidgets('changed says returned differently', (tester) async {
      await _pumpCard(
        tester,
        _manualExplanation(PatternConfidenceExplanationState.changed),
      );

      expect(find.textContaining('returned differently'), findsOneWidget);
    });

    testWidgets('needs fresh proof says needs newer saved moment', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _manualExplanation(PatternConfidenceExplanationState.needsFreshProof),
      );

      expect(find.textContaining('needs a newer saved moment'), findsOneWidget);
    });

    testWidgets('no percentage confidence', (tester) async {
      await _pumpCard(tester, _explanationFor(_threeRelatedRepeatEntries()));

      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('percent'), findsNothing);
    });

    testWidgets('no transcript/body/private text', (tester) async {
      await _pumpCard(tester, _explanationFor(_threeRelatedRepeatEntries()));

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('localAudioPath'), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('no Pro CTA', (tester) async {
      await _pumpCard(tester, _explanationFor(_threeRelatedRepeatEntries()));

      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.byKey(const Key('pro_evidence_value_cta')), findsNothing);
    });

    testWidgets('compact mode hides intro footer and differentiation', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        _explanationFor(_threeRelatedRepeatEntries()),
        compact: true,
      );

      expect(find.text(PatternConfidenceCopy.explanationIntro), findsNothing);
      expect(find.text(PatternConfidenceCopy.explanationFooter), findsNothing);
      expect(
        find.text(PatternConfidenceCopy.explanationDifferentiation),
        findsNothing,
      );
    });

    testWidgets('analytics metadata only', (tester) async {
      await _pumpCard(tester, _explanationFor(_threeRelatedRepeatEntries()));

      expect(analyticsEvents, hasLength(1));
      final record = analyticsEvents.single;
      expect(record.event, PatternConfidenceAnalytics.seenEvent);
      expect(
        record.props.keys,
        containsAll([
          'source',
          'entry_count',
          'confidence_state',
          'has_confirmed_repeat',
          'has_belief_surface',
        ]),
      );
      for (final value in record.props.values) {
        final text = value.toString().toLowerCase();
        expect(text, isNot(contains('transcript')));
        expect(text, isNot(contains(_strongRepeat.toLowerCase())));
      }
    });
  });

  group('Pattern confidence copy guard', () {
    test('copy avoids percentages and fake scores', () {
      for (final line in PatternConfidenceCopy.allVisibleStrings()) {
        expect(line, isNot(contains('%')));
        expect(line.toLowerCase(), isNot(contains('confidence score')));
        expect(line.toLowerCase(), isNot(contains('percent')));
      }
    });

    test('copy passes advice guard', () {
      for (final line in PatternConfidenceCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('no therapy or monetisation claims in explanation copy', () {
      final blob = PatternConfidenceCopy.allExplanationStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('treatment')));
      expect(blob, isNot(contains('subscribe')));
      expect(blob, contains('chatgpt'));
    });
  });

  group('Pattern confidence placement', () {
    test('patterns screen renders card after present day relevance', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final relevanceIndex = source.indexOf('PresentDayRelevanceCard(');
      final cardIndex = source.indexOf('PatternConfidenceCard(');
      final proBridgeIndex = source.indexOf(
        "analyticsSource: 'patterns_post_proof_pro_evidence_value'",
      );
      expect(relevanceIndex, greaterThan(0));
      expect(cardIndex, greaterThan(relevanceIndex));
      expect(proBridgeIndex, greaterThan(cardIndex));
    });

    test('record screen renders compact card after present day relevance', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final relevanceIndex = source.indexOf(
        'showPresentDayRelevanceOnRecordReady',
      );
      final cardIndex = source.indexOf(
        'showPatternConfidenceExplanationOnRecordReady',
      );
      expect(relevanceIndex, greaterThan(0));
      expect(cardIndex, greaterThan(relevanceIndex));
      expect(source.indexOf('compact: true,'), greaterThan(cardIndex));
    });

    test('weekly review renders compact card near weekly archive review', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final weeklyCardIndex = source.indexOf(
        'if (showPatternConfidenceExplanationNearWeeklyReview &&',
      );
      final weeklyReviewIndex = source.indexOf(
        'weeklyReviewSurface.WeeklyArchiveReviewCard(',
      );
      expect(weeklyCardIndex, greaterThan(0));
      expect(weeklyReviewIndex, greaterThan(weeklyCardIndex));
      expect(
        source.substring(weeklyCardIndex, weeklyReviewIndex),
        contains('PatternConfidenceCard('),
      );
      expect(
        source.substring(weeklyCardIndex, weeklyReviewIndex),
        contains("source: 'patterns_weekly_review'"),
      );
    });
  });

  group('integration safety', () {
    test('first proof flow still works', () {
      final payoff = FirstProofPayoffEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      expect(payoff, isNotNull);
      expect(payoff!.hasSnippets, isTrue);
    });

    test('belief change moment still works with changing evidence', () {
      final moment = BeliefChangeMomentEngine.build(
        entries: _fourWithDifferentLatestPhrase(),
        returnChecks: [
          _answeredRecord(
            entryId: 'e4',
            choice: RepeatReturnCheckChoice.changed,
          ),
        ],
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(moment, isNotNull);
    });

    test('confirmed repeat foundation still works', () {
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
          _threeRelatedRepeatEntries(),
        ),
        isTrue,
      );
    });

    test('feature files avoid billing and signing surfaces', () {
      const paths = [
        'lib/features/pattern_confidence/pattern_confidence_copy.dart',
        'lib/features/pattern_confidence/pattern_confidence_model.dart',
        'lib/features/pattern_confidence/pattern_confidence_engine.dart',
        'lib/features/pattern_confidence/pattern_confidence_analytics.dart',
        'lib/widgets/patterns/pattern_confidence_badge.dart',
        'lib/widgets/patterns/pattern_confidence_card.dart',
      ];
      for (final path in paths) {
        final content = File(path).readAsStringSync().toLowerCase();
        expect(content, isNot(contains('revenuecat')));
        expect(content, isNot(contains('restorepurchase')));
        expect(content, isNot(contains('billing/')));
        expect(content, isNot(contains('build_number')));
      }
    });

    test('analytics module is metadata only', () {
      final content = File(
        'lib/features/pattern_confidence/pattern_confidence_analytics.dart',
      ).readAsStringSync().toLowerCase();
      expect(content, contains('pattern_confidence_seen'));
      expect(content, contains('entry_count'));
      expect(content, contains('confidence_state'));
      expect(content, isNot(contains('transcript')));
    });
  });
}
