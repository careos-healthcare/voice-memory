import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:voicememory_mobile/features/not_relevant_recovery/not_relevant_recovery_analytics.dart';
import 'package:voicememory_mobile/features/not_relevant_recovery/not_relevant_recovery_copy.dart';
import 'package:voicememory_mobile/features/not_relevant_recovery/not_relevant_recovery_engine.dart';
import 'package:voicememory_mobile/features/not_relevant_recovery/not_relevant_recovery_model.dart';
import 'package:voicememory_mobile/features/not_relevant_recovery/not_relevant_recovery_store.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/not_relevant_recovery_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/not_relevant_recovery/unused.json'));

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

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
}) =>
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

Future<void> _pumpCard(
  WidgetTester tester,
  NotRelevantRecoveryResult result, {
  NotRelevantRecoveryStore? store,
  NotRelevantRecoveryActionType? initialAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NotRelevantRecoveryCard.test(
          result: result,
          source: 'test',
          store: store,
          initialAction: initialAction,
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
          'test/tmp/not_relevant_recovery/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/not_relevant_recovery/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    NotRelevantRecoveryAnalytics.resetForTest();
    NotRelevantRecoveryAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await NotRelevantRecoveryStore.resetForTest(prefs);
    await BetaProofFeedbackStore.resetForTest(prefs);
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
  });

  tearDown(NotRelevantRecoveryAnalytics.resetForTest);

  group('NotRelevantRecoveryCopy', () {
    test('passes proof surface advice guard', () {
      for (final line in NotRelevantRecoveryCopy.allVisibleStrings) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('returned-after-correction copy exists', () {
      expect(
        NotRelevantRecoveryCopy.returnedAfterCorrectionLine,
        contains('background'),
      );
    });
  });

  group('NotRelevantRecoveryEngine triggers', () {
    test('beta proof feedback Not relevant creates recovery state', () async {
      final entries = _threeRelatedEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: entries.length,
      );
      await NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
        entries: entries,
        source: 'test',
      );

      final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
      expect(
        CorrectionMemoryStore.recordFor(proofKey)?.state,
        CorrectionMemoryState.faded,
      );
      expect(
        NotRelevantRecoveryEngine.build(entries: entries, source: 'test')
            .shouldShow,
        isTrue,
      );
    });

    test('CurrentRelevance not really creates recovery state', () async {
      final entries = _threeRelatedEntries();
      final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
      await CurrentRelevanceStore.instance().saveSelection(
        proofKey: proofKey,
        answer: CurrentRelevanceAnswer.notReally,
        entryCountAtCapture: entries.length,
      );
      await NotRelevantRecoveryEngine.syncBackgroundCorrectionIfNeeded(
        entries: entries,
        source: 'test',
      );

      expect(
        NotRelevantRecoveryEngine.build(entries: entries, source: 'test')
            .shouldShow,
        isTrue,
      );
    });

    test('hidden without correction state', () {
      final entries = _threeRelatedEntries();
      expect(
        NotRelevantRecoveryEngine.build(entries: entries, source: 'test')
            .shouldShow,
        isFalse,
      );
    });

    test('hidden during recording', () {
      final entries = _threeRelatedEntries();
      final result = NotRelevantRecoveryResult(
        shouldShow: true,
        proofKey: '1|2|3',
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasFreshReturn: false,
        title: NotRelevantRecoveryCopy.title,
        body: NotRelevantRecoveryCopy.body,
        correctionLine: NotRelevantRecoveryCopy.correctionLine,
        returnLine: NotRelevantRecoveryCopy.returnLine,
        returnedAfterCorrectionLine:
            NotRelevantRecoveryCopy.returnedAfterCorrectionLine,
      );

      expect(
        NotRelevantRecoveryEngine.shouldShow(
          result: result,
          parentVisible: true,
          isRecording: true,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden degraded and during WhatChanged', () {
      final result = NotRelevantRecoveryEngine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
      ).copyWithHiddenAsVisible();

      expect(
        NotRelevantRecoveryEngine.shouldShow(
          result: result,
          parentVisible: true,
          isRecording: false,
          isDegradedTranscriptState: true,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
      expect(
        NotRelevantRecoveryEngine.shouldShow(
          result: result,
          parentVisible: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });
  });

  group('NotRelevantRecoveryCard', () {
    NotRelevantRecoveryResult _visibleResult() => NotRelevantRecoveryResult(
          shouldShow: true,
          proofKey: '1|2|3',
          entryCount: 3,
          source: 'test',
          hasConfirmedRepeat: true,
          hasFreshReturn: false,
          title: NotRelevantRecoveryCopy.title,
          body: NotRelevantRecoveryCopy.body,
          correctionLine: NotRelevantRecoveryCopy.correctionLine,
          returnLine: NotRelevantRecoveryCopy.returnLine,
          returnedAfterCorrectionLine:
              NotRelevantRecoveryCopy.returnedAfterCorrectionLine,
        );

    testWidgets('renders title and background copy', (tester) async {
      await _pumpCard(tester, _visibleResult());

      expect(find.byKey(const Key('not_relevant_recovery_card')), findsOneWidget);
      expect(find.text(NotRelevantRecoveryCopy.title), findsOneWidget);
      expect(find.textContaining('background unless it returns'), findsOneWidget);
    });

    testWidgets('renders correction changes timeline weighting', (tester) async {
      await _pumpCard(tester, _visibleResult());

      expect(find.text(NotRelevantRecoveryCopy.correctionLine), findsOneWidget);
    });

    testWidgets('Keep as background persists background state', (tester) async {
      final entries = _threeRelatedEntries();
      final store = NotRelevantRecoveryStore.forPrefs(prefs);
      await _pumpCard(tester, _visibleResult(), store: store);

      await tester.tap(
        find.byKey(const Key('not_relevant_recovery_keep_as_background')),
      );
      await tester.pumpAndSettle();

      final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
      expect(
        CorrectionMemoryStore.recordFor(proofKey)?.state,
        CorrectionMemoryState.faded,
      );
      expect(
        find.text(NotRelevantRecoveryCopy.keepAsBackgroundFollowUp),
        findsOneWidget,
      );
    });

    testWidgets('Watch lightly persists light watch state', (tester) async {
      final entries = _threeRelatedEntries();
      final store = NotRelevantRecoveryStore.forPrefs(prefs);
      await _pumpCard(tester, _visibleResult(), store: store);

      await tester.tap(
        find.byKey(const Key('not_relevant_recovery_watch_lightly')),
      );
      await tester.pumpAndSettle();

      final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
      expect(
        CorrectionMemoryStore.recordFor(proofKey)?.state,
        CorrectionMemoryState.partlyCurrent,
      );
      expect(
        find.text(NotRelevantRecoveryCopy.watchLightlyFollowUp),
        findsOneWidget,
      );
    });

    testWidgets('It is relevant again persists stillCurrent state', (tester) async {
      final entries = _threeRelatedEntries();
      final store = NotRelevantRecoveryStore.forPrefs(prefs);
      await _pumpCard(tester, _visibleResult(), store: store);

      await tester.tap(
        find.byKey(const Key('not_relevant_recovery_relevant_again')),
      );
      await tester.pumpAndSettle();

      final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
      expect(
        CorrectionMemoryStore.recordFor(proofKey)?.state,
        CorrectionMemoryState.stillCurrent,
      );
      expect(
        find.text(NotRelevantRecoveryCopy.relevantAgainFollowUp),
        findsOneWidget,
      );
    });

    testWidgets('no transcript/body/private text or Pro CTA', (tester) async {
      await _pumpCard(tester, _visibleResult());

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('therapy'), findsNothing);
    });
  });

  group('Downstream weighting integration', () {
    Future<void> _saveFaded(List<JournalEntry> entries) async {
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: entries.length,
      );
      await NotRelevantRecoveryEngine.applyAction(
        result: NotRelevantRecoveryResult(
          shouldShow: true,
          proofKey: CurrentRelevanceStore.proofKeyFor(entries),
          entryCount: entries.length,
          source: 'test',
          hasConfirmedRepeat:
              EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
          hasFreshReturn: false,
          title: NotRelevantRecoveryCopy.title,
          body: NotRelevantRecoveryCopy.body,
          correctionLine: NotRelevantRecoveryCopy.correctionLine,
          returnLine: NotRelevantRecoveryCopy.returnLine,
          returnedAfterCorrectionLine:
              NotRelevantRecoveryCopy.returnedAfterCorrectionLine,
        ),
        actionType: NotRelevantRecoveryActionType.keepAsBackground,
        source: 'test',
        store: NotRelevantRecoveryStore.forPrefs(prefs),
      );
    }

    test('PresentDayRelevance uses recovery state', () async {
      final entries = _threeRelatedEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: entries.length,
      );
      await _saveFaded(entries);

      final present = PresentDayRelevanceEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
      );
      expect(present?.relevanceState, PresentDayRelevanceState.fading);
    });

    test('EvidenceWeighting uses recovery state', () async {
      final entries = _threeRelatedEntries();
      await _saveFaded(entries);

      final weighting = EvidenceWeightingEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(weighting?.primaryState, EvidenceWeightState.fading);
    });

    test('ArchiveTimelineSpine current weight changes', () async {
      final entries = _threeRelatedEntries();
      await _saveFaded(entries);

      final spine = ArchiveTimelineSpineEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine?.currentWeight, ArchiveTimelineSpineCurrentWeight.corrected);
      expect(spine?.hasCorrection, isTrue);
    });

    test('TimelineProofMoment shows correction row', () async {
      final entries = _threeRelatedEntries();
      await _saveFaded(entries);

      final moment = TimelineProofMomentEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(moment?.hasCorrection, isTrue);
      expect(
        moment?.rows.any((row) => row.label.contains('You corrected this')),
        isTrue,
      );
    });

    test('fresh return is not permanently suppressed', () async {
      final entries = [
        ..._threeRelatedEntries(anchor: _now.subtract(const Duration(days: 10))),
        _entry(
          '4',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: _now,
        ),
      ];
      await _saveFaded(entries.sublist(0, 3));
      final proofKey = CurrentRelevanceStore.proofKeyFor(entries.sublist(0, 3));
      await CorrectionMemoryStore.instance().saveFromAnswer(
        proofKey: proofKey,
        answer: CurrentRelevanceAnswer.notReally,
        entryCountAtCapture: 3,
        hasConfirmedRepeat: true,
      );

      final spine = ArchiveTimelineSpineEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine?.currentWeight, isNot(ArchiveTimelineSpineCurrentWeight.corrected));
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
    });
  });

  group('NotRelevantRecoveryAnalytics', () {
    testWidgets('metadata-only analytics', (tester) async {
      final entries = _threeRelatedEntries();
      final result = NotRelevantRecoveryEngine.build(
        entries: entries,
        source: 'test',
      );
      final built = result.shouldShow
          ? result
          : NotRelevantRecoveryResult(
              shouldShow: true,
              proofKey: CurrentRelevanceStore.proofKeyFor(entries),
              entryCount: entries.length,
              source: 'test',
              hasConfirmedRepeat: true,
              hasFreshReturn: false,
              title: NotRelevantRecoveryCopy.title,
              body: NotRelevantRecoveryCopy.body,
              correctionLine: NotRelevantRecoveryCopy.correctionLine,
              returnLine: NotRelevantRecoveryCopy.returnLine,
              returnedAfterCorrectionLine:
                  NotRelevantRecoveryCopy.returnedAfterCorrectionLine,
            );
      final store = NotRelevantRecoveryStore.forPrefs(prefs);
      await _pumpCard(tester, built, store: store);
      await tester.tap(
        find.byKey(const Key('not_relevant_recovery_keep_as_background')),
      );
      await tester.pumpAndSettle();

      expect(analyticsEvents.length, 2);
      for (final event in analyticsEvents) {
        expect(event.props.containsKey('entry_count'), isTrue);
        expect(event.props.containsKey('has_confirmed_repeat'), isTrue);
        expect(event.props.containsKey('has_fresh_return'), isTrue);
        expect(event.props.keys.any((key) => key.contains('transcript')), isFalse);
      }
      expect(analyticsEvents.last.props['action_type'], 'keep_as_background');
    });
  });
}

extension _TestResultHelpers on NotRelevantRecoveryResult {
  NotRelevantRecoveryResult copyWithHiddenAsVisible() => NotRelevantRecoveryResult(
        shouldShow: true,
        proofKey: proofKey.isEmpty ? '1|2|3' : proofKey,
        entryCount: entryCount == 0 ? 3 : entryCount,
        source: source,
        hasConfirmedRepeat: true,
        hasFreshReturn: hasFreshReturn,
        title: title,
        body: body,
        correctionLine: correctionLine,
        returnLine: returnLine,
        returnedAfterCorrectionLine: returnedAfterCorrectionLine,
      );

  NotRelevantRecoveryResult copyWithForcedVisible({
    required String proofKey,
    required int entryCount,
  }) =>
      NotRelevantRecoveryResult(
        shouldShow: true,
        proofKey: proofKey,
        entryCount: entryCount,
        source: source,
        hasConfirmedRepeat: true,
        hasFreshReturn: false,
        title: title,
        body: body,
        correctionLine: correctionLine,
        returnLine: returnLine,
        returnedAfterCorrectionLine: returnedAfterCorrectionLine,
      );
}
