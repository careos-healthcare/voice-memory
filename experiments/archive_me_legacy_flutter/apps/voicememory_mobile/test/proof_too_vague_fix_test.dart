import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/proof_specificity_boost/proof_specificity_boost_analytics.dart';
import 'package:voicememory_mobile/features/proof_specificity_boost/proof_specificity_boost_copy.dart';
import 'package:voicememory_mobile/features/proof_specificity_boost/proof_specificity_boost_engine.dart';
import 'package:voicememory_mobile/features/proof_specificity_boost/proof_specificity_boost_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/proof_specificity_boost_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/proof_too_vague_fix/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? _now,
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

List<JournalEntry> _threeRelatedEntries({DateTime? anchor}) {
  final base = anchor ?? _now;
  return [
    _entry(
      '1',
      _strongRepeat,
      createdAt: base.subtract(const Duration(days: 2)),
    ),
    _entry(
      '2',
      'Same thing — said yes when I had no capacity for one more thing.',
      createdAt: base.subtract(const Duration(days: 1)),
    ),
    _entry(
      '3',
      'I said yes again even though I had no capacity for one more ask.',
      createdAt: base,
    ),
  ];
}

ProofSpecificityBoostResult _boostResultFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  List<String> beliefEvidencePhrases = const [],
  String source = 'test',
}) => ProofSpecificityBoostEngine.build(
  entries: entries,
  beliefSurfaceVisible: beliefSurfaceVisible,
  source: source,
  beliefEvidencePhrases: beliefEvidencePhrases,
);

Future<void> _pumpBoostCard(
  WidgetTester tester,
  ProofSpecificityBoostResult result, {
  ProofSpecificityBoostSurface surface =
      ProofSpecificityBoostSurface.timelineProofMoment,
  String source = 'test',
  String proofKey = 'proof-key',
  ProofSpecificityBoostStore? store,
  ProofSpecificityBoostAnswerType? initialAnswer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProofSpecificityBoostCard.test(
          result: result,
          surface: surface,
          source: source,
          hasConfirmedRepeat:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
                _threeRelatedEntries(),
              ),
          proofKey: proofKey,
          store: store,
          initialAnswer: initialAnswer,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  late _MemoryPrefs prefs;

  setUp(() async {
    prefs = _MemoryPrefs();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/proof_too_vague_fix/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/proof_too_vague_fix/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    ProofSpecificityBoostAnalytics.resetForTest();
    ProofSpecificityBoostAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await ProofSpecificityBoostStore.resetForTest(prefs);
    await BetaProofFeedbackStore.resetForTest(prefs);
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
  });

  tearDown(() {
    ProofSpecificityBoostAnalytics.resetForTest();
  });

  group('ProofSpecificityBoostCopy', () {
    test('passes proof surface advice guard', () {
      for (final line in ProofSpecificityBoostCopy.all) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('does not include therapy or medical claims', () {
      for (final line in ProofSpecificityBoostCopy.all) {
        expect(line.toLowerCase(), isNot(contains('therapy')));
        expect(line.toLowerCase(), isNot(contains('diagnosis')));
        expect(line.toLowerCase(), isNot(contains('mental health')));
      }
    });
  });

  group('ProofSpecificityBoostEngine', () {
    test('qualifies after beta too vague feedback', () async {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.tooVague,
        entryCount: entries.length,
      );

      expect(
        ProofSpecificityBoostEngine.qualifiesForDisplay(
          result: result,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
        ),
        isTrue,
      );
    });

    test('patterns only qualifies after beta too vague', () async {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);

      expect(
        ProofSpecificityBoostEngine.qualifiesForDisplay(
          result: result,
          surface: ProofSpecificityBoostSurface.patterns,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
        ),
        isFalse,
      );

      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.tooVague,
        entryCount: entries.length,
      );

      expect(
        ProofSpecificityBoostEngine.qualifiesForDisplay(
          result: result,
          surface: ProofSpecificityBoostSurface.patterns,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
        ),
        isTrue,
      );
    });

    test('qualifies on first proof payoff with confirmed repeat', () {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);

      expect(
        ProofSpecificityBoostEngine.qualifiesForDisplay(
          result: result,
          surface: ProofSpecificityBoostSurface.firstProofPayoff,
          timelineProofVisible: false,
          firstProofPayoffVisible: true,
        ),
        isTrue,
      );
    });

    test('hidden during recording', () {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);

      expect(
        ProofSpecificityBoostEngine.shouldShow(
          result: result,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: true,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden when degraded transcript', () {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);

      expect(
        ProofSpecificityBoostEngine.shouldShow(
          result: result,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: false,
          isDegradedTranscriptState: true,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during WhatChanged', () {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);

      expect(
        ProofSpecificityBoostEngine.shouldShow(
          result: result,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden without confirmed repeat or belief surface', () {
      final entries = [_entry('1', _strongRepeat)];
      final result = ProofSpecificityBoostEngine.build(
        entries: entries,
        beliefSurfaceVisible: false,
        source: 'test',
      );

      expect(result.shouldShow, isFalse);
    });

    test('build anchors are sanitized summaries not full transcripts', () {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);

      for (final anchor in result.evidenceAnchors) {
        for (final entry in entries) {
          expect(anchor == entry.transcript.trim(), isFalse);
        }
      }
    });
  });

  group('ProofSpecificityBoostCard', () {
    testWidgets('renders "Why this is not just a guess"', (tester) async {
      await _pumpBoostCard(tester, _boostResultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('proof_specificity_boost_card')),
        findsOneWidget,
      );
      expect(find.text(ProofSpecificityBoostCopy.title), findsOneWidget);
    });

    testWidgets('renders repeated signal heading', (tester) async {
      await _pumpBoostCard(tester, _boostResultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('proof_specificity_boost_evidence_heading')),
        findsOneWidget,
      );
      expect(
        find.text(ProofSpecificityBoostCopy.evidenceHeading),
        findsOneWidget,
      );
    });

    testWidgets('renders safe fallback when no safe anchors', (tester) async {
      final result = ProofSpecificityBoostResult(
        shouldShow: true,
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasBeliefSurface: false,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        hasSafeAnchor: false,
      );
      await _pumpBoostCard(tester, result);

      expect(
        find.byKey(const Key('proof_specificity_boost_fallback_anchor')),
        findsOneWidget,
      );
      expect(
        find.text(ProofSpecificityBoostCopy.fallbackAnchor),
        findsOneWidget,
      );
    });

    testWidgets('renders safe anchors when available', (tester) async {
      const anchor = 'said yes again';
      final result = ProofSpecificityBoostResult(
        shouldShow: true,
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasBeliefSurface: true,
        evidenceAnchors: const [anchor],
        usesFallbackEvidenceLine: false,
        hasSafeAnchor: true,
      );
      await _pumpBoostCard(tester, result);

      expect(find.text(anchor), findsOneWidget);
      expect(
        find.byKey(const Key('proof_specificity_boost_fallback_anchor')),
        findsNothing,
      );
    });

    testWidgets('renders specificity rows', (tester) async {
      await _pumpBoostCard(tester, _boostResultFor(_threeRelatedEntries()));

      for (final row in ProofSpecificityBoostCopy.specificityRows) {
        expect(find.text(row), findsOneWidget);
      }
    });

    testWidgets('does not expose raw transcript/body/private text', (
      tester,
    ) async {
      await _pumpBoostCard(tester, _boostResultFor(_threeRelatedEntries()));

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('localAudioPath'), findsNothing);
      expect(find.textContaining('transcript'), findsNothing);
    });

    testWidgets('renders "This is not a label"', (tester) async {
      await _pumpBoostCard(tester, _boostResultFor(_threeRelatedEntries()));

      expect(
        find.byKey(const Key('proof_specificity_boost_boundary_line')),
        findsOneWidget,
      );
      expect(find.text(ProofSpecificityBoostCopy.boundaryLine), findsOneWidget);
      expect(find.textContaining('This is not a label'), findsOneWidget);
    });

    testWidgets('answer Too vague stores local feedback', (tester) async {
      final store = ProofSpecificityBoostStore.forPrefs(prefs);
      await _pumpBoostCard(
        tester,
        _boostResultFor(_threeRelatedEntries()),
        store: store,
      );

      await tester.tap(
        find.byKey(const Key('proof_specificity_boost_too_vague')),
      );
      await tester.pumpAndSettle();

      expect(
        ProofSpecificityBoostStore.recordFor(
          ProofSpecificityBoostSurface.timelineProofMoment,
        ).answerType,
        ProofSpecificityBoostAnswerType.tooVague,
      );
      expect(
        find.text(ProofSpecificityBoostCopy.tooVagueFollowUp),
        findsOneWidget,
      );
    });

    testWidgets('answer Not relevant stores light correction if safe', (
      tester,
    ) async {
      final entries = _threeRelatedEntries();
      final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
      expect(proofKey, isNotEmpty);
      final store = ProofSpecificityBoostStore.forPrefs(prefs);
      await _pumpBoostCard(
        tester,
        _boostResultFor(entries),
        store: store,
        proofKey: proofKey,
      );

      await tester.tap(
        find.byKey(const Key('proof_specificity_boost_not_relevant')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        ProofSpecificityBoostStore.recordFor(
          ProofSpecificityBoostSurface.timelineProofMoment,
        ).answerType,
        ProofSpecificityBoostAnswerType.notRelevant,
      );
      expect(CorrectionMemoryStore.recordFor(proofKey)?.state.name, isNotNull);
      expect(
        find.text(ProofSpecificityBoostCopy.notRelevantFollowUp),
        findsOneWidget,
      );
    });

    testWidgets('does not include Pro CTA', (tester) async {
      await _pumpBoostCard(tester, _boostResultFor(_threeRelatedEntries()));

      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.byKey(const Key('pro_evidence_value_cta')), findsNothing);
    });
  });

  group('ProofSpecificityBoostAnalytics', () {
    testWidgets('metadata-only analytics on seen and answered', (tester) async {
      final store = ProofSpecificityBoostStore.forPrefs(prefs);
      final result = _boostResultFor(_threeRelatedEntries());
      await _pumpBoostCard(tester, result, store: store);
      await tester.tap(find.byKey(const Key('proof_specificity_boost_yes')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(analyticsEvents.length, 2);
      expect(analyticsEvents.first.event, 'proof_specificity_boost_seen');
      expect(analyticsEvents.last.event, 'proof_specificity_boost_answered');

      for (final event in analyticsEvents) {
        expect(event.props.containsKey('source'), isTrue);
        expect(event.props.containsKey('surface'), isTrue);
        expect(event.props.containsKey('entry_count'), isTrue);
        expect(event.props.containsKey('has_confirmed_repeat'), isTrue);
        expect(event.props.containsKey('has_safe_anchor'), isTrue);
        expect(
          event.props.keys.any((key) => key.contains('transcript')),
          isFalse,
        );
        expect(event.props.keys.any((key) => key.contains('body')), isFalse);
      }

      expect(analyticsEvents.last.props['answer_type'], 'yes');
    });
  });

  group('Placement contracts', () {
    test('appears under TimelineProofMomentCard when qualified', () {
      final result = ProofSpecificityBoostResult(
        shouldShow: true,
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasBeliefSurface: false,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        hasSafeAnchor: false,
      );

      expect(
        ProofSpecificityBoostEngine.shouldRender(
          result: result,
          surface: ProofSpecificityBoostSurface.timelineProofMoment,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('appears under FirstProofPayoffCard when safe', () {
      final entries = _threeRelatedEntries();
      final result = _boostResultFor(entries);

      expect(
        ProofSpecificityBoostEngine.shouldRender(
          result: result,
          surface: ProofSpecificityBoostSurface.firstProofPayoff,
          parentVisible: true,
          timelineProofVisible: false,
          firstProofPayoffVisible: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });
  });
}
