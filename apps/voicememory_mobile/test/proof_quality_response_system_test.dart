import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_analytics.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_copy.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_engine.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_store.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/proof_quality_response_card.dart';
import 'support/test_storage_sandbox.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/proof_quality_response/unused.json'));

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
const _patternLabelOnly = 'work pressure';
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

Future<void> _saveBetaFeedback(
  _MemoryPrefs prefs,
  BetaProofFeedbackType type, {
  BetaProofFeedbackSurface surface =
      BetaProofFeedbackSurface.timelineProofMoment,
  int entryCount = 3,
}) => BetaProofFeedbackStore.forPrefs(
  prefs,
).saveAnswer(surface: surface, feedbackType: type, entryCount: entryCount);

Future<void> _pumpCard(
  WidgetTester tester,
  ProofQualityResponseResult result, {
  ProofQualityResponseStore? store,
  ProofQualityResponseRecord? initialRecord,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProofQualityResponseCard.test(
          result: result,
          source: 'test',
          store: store,
          initialRecord: initialRecord,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late TestStorageSandbox sandbox;
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  late _MemoryPrefs prefs;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.enabledOverride = true;
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    ProofQualityResponseAnalytics.resetForTest();
    ProofQualityResponseAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await ProofQualityResponseStore.resetForTest(prefs);
    await BetaProofFeedbackStore.resetForTest(prefs);
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  tearDown(() {
    ProofQualityResponseAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
  });

  group('ProofQualityResponseCopy', () {
    test('passes proof surface advice guard', () {
      for (final line in ProofQualityResponseCopy.allVisibleStrings) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('ProofQualityResponseEngine too vague', () {
    test('shows Make this more specific', () async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.tooVague);

      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );

      expect(result.shouldShow, isTrue);
      expect(result.title, ProofQualityResponseCopy.tooVagueTitle);
    });

    test('uses fallback copy when no safe anchors resolved', () {
      final result = ProofQualityResponseResult(
        shouldShow: true,
        feedbackState: ProofQualityFeedbackState.tooVague,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        proofKey: '1|2|3',
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasSafeAnchor: false,
        hasFreshReturn: false,
        title: ProofQualityResponseCopy.tooVagueTitle,
        body: ProofQualityResponseCopy.tooVagueBody,
        footer: ProofQualityResponseCopy.footer,
        rows: ProofQualityResponseCopy.tooVagueRows,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        deltaLine: null,
        returnedAfterCorrectionLine:
            ProofQualityResponseCopy.returnedAfterCorrectionLine,
        stillTooVagueFollowUp: false,
      );

      expect(result.usesFallbackEvidenceLine, isTrue);
    });
  });

  group('ProofQualityResponseCard too vague', () {
    testWidgets('renders fallback when no safe anchor', (tester) async {
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.tooVague);
      final result = ProofQualityResponseResult(
        shouldShow: true,
        feedbackState: ProofQualityFeedbackState.tooVague,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        proofKey: '1|2|3',
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasSafeAnchor: false,
        hasFreshReturn: false,
        title: ProofQualityResponseCopy.tooVagueTitle,
        body: ProofQualityResponseCopy.tooVagueBody,
        footer: ProofQualityResponseCopy.footer,
        rows: ProofQualityResponseCopy.tooVagueRows,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        deltaLine: null,
        returnedAfterCorrectionLine:
            ProofQualityResponseCopy.returnedAfterCorrectionLine,
        stillTooVagueFollowUp: false,
      );

      await _pumpCard(tester, result);

      expect(
        find.text(ProofQualityResponseCopy.tooVagueFallback),
        findsOneWidget,
      );
      for (final row in ProofQualityResponseCopy.tooVagueRows) {
        expect(find.text(row), findsOneWidget);
      }
    });

    testWidgets('renders evidence anchors when safe anchors exist', (
      tester,
    ) async {
      const anchor = 'said yes again';
      final result = ProofQualityResponseResult(
        shouldShow: true,
        feedbackState: ProofQualityFeedbackState.tooVague,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        proofKey: '1|2|3',
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasSafeAnchor: true,
        hasFreshReturn: false,
        title: ProofQualityResponseCopy.tooVagueTitle,
        body: ProofQualityResponseCopy.tooVagueBody,
        footer: ProofQualityResponseCopy.footer,
        rows: ProofQualityResponseCopy.tooVagueRows,
        evidenceAnchors: const [anchor],
        usesFallbackEvidenceLine: false,
        deltaLine: null,
        returnedAfterCorrectionLine:
            ProofQualityResponseCopy.returnedAfterCorrectionLine,
        stillTooVagueFollowUp: false,
      );

      await _pumpCard(tester, result);

      expect(find.text(anchor), findsOneWidget);
      expect(
        find.text(ProofQualityResponseCopy.tooVagueFallback),
        findsNothing,
      );
    });
  });

  group('ProofQualityResponseEngine already knew this', () {
    test('shows What changed this time', () async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.alreadyKnew);

      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );

      expect(result.title, ProofQualityResponseCopy.alreadyKnewTitle);
      expect(result.body, contains(ProofQualityResponseCopy.alreadyKnewBody));
    });

    testWidgets('renders change-focused rows without pattern label only', (
      tester,
    ) async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.alreadyKnew);
      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );

      await _pumpCard(tester, result);

      expect(
        find.text(ProofQualityResponseCopy.alreadyKnewTitle),
        findsOneWidget,
      );
      expect(
        find.text(ProofQualityResponseCopy.alreadyKnewDeltaLine),
        findsOneWidget,
      );
      for (final row in ProofQualityResponseCopy.alreadyKnewRows) {
        expect(find.text(row), findsOneWidget);
      }
      expect(find.text(_patternLabelOnly), findsNothing);
    });

    testWidgets('answer stores local proof quality response', (tester) async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.alreadyKnew);
      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      final store = ProofQualityResponseStore.forPrefs(prefs);

      await _pumpCard(tester, result, store: store);
      await tester.tap(
        find.byKey(const Key('proof_quality_response_felt_lighter')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        ProofQualityResponseStore.isAnswered(
          surface: ProofQualityResponseSurface.timelineProofMoment,
          proofKey: result.proofKey,
        ),
        isTrue,
      );
      expect(
        find.text(ProofQualityResponseCopy.feltLighterFollowUp),
        findsOneWidget,
      );
    });
  });

  group('ProofQualityResponseEngine not relevant', () {
    testWidgets('shows background correction choices', (tester) async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.notRelevant);
      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );

      await _pumpCard(tester, result);

      expect(
        find.text(ProofQualityResponseCopy.notRelevantTitle),
        findsOneWidget,
      );
      expect(
        find.text(ProofQualityResponseCopy.keepAsBackgroundLabel),
        findsOneWidget,
      );
      expect(
        find.text(ProofQualityResponseCopy.watchLightlyLabel),
        findsOneWidget,
      );
      expect(
        find.text(ProofQualityResponseCopy.relevantAgainLabel),
        findsOneWidget,
      );
    });

    testWidgets('updates correction state where safe', (tester) async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.notRelevant);
      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      final store = ProofQualityResponseStore.forPrefs(prefs);

      await _pumpCard(tester, result, store: store);
      await tester.tap(
        find.byKey(const Key('proof_quality_response_keep_as_background')),
      );
      await tester.pumpAndSettle();

      expect(
        ProofQualityResponseStore.isAnswered(
          surface: ProofQualityResponseSurface.timelineProofMoment,
          proofKey: result.proofKey,
        ),
        isTrue,
      );
      expect(
        find.text(ProofQualityResponseCopy.keepAsBackgroundFollowUp),
        findsOneWidget,
      );
    });

    test('fresh return after background is not suppressed', () async {
      final entries = [
        ..._threeRelatedEntries(
          anchor: _now.subtract(const Duration(days: 10)),
        ),
        _entry(
          '4',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: _now,
        ),
      ];
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.notRelevant);
      await ProofQualityResponseEngine.applyNotRelevantAction(
        result: ProofQualityResponseEngine.build(
          entries: entries.sublist(0, 3),
          surface: ProofQualityResponseSurface.timelineProofMoment,
          source: 'test',
        ),
        action: ProofQualityNotRelevantAction.keepAsBackground,
        source: 'test',
        store: ProofQualityResponseStore.forPrefs(prefs),
      );

      final spine = ArchiveTimelineSpineEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(
        spine?.currentWeight,
        isNot(ArchiveTimelineSpineCurrentWeight.corrected),
      );
      expect(
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
        isTrue,
      );
    });
  });

  group('ProofQualityResponseEngine visibility', () {
    test('hidden when feedback is useful', () async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.useful);

      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );

      expect(result.shouldShow, isFalse);
    });

    test('hidden when no feedback', () {
      final result = ProofQualityResponseEngine.build(
        entries: _threeRelatedEntries(),
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      expect(result.shouldShow, isFalse);
    });

    test('hidden degraded', () {
      final result = ProofQualityResponseResult(
        shouldShow: true,
        feedbackState: ProofQualityFeedbackState.tooVague,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        proofKey: '1|2|3',
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasSafeAnchor: false,
        hasFreshReturn: false,
        title: ProofQualityResponseCopy.tooVagueTitle,
        body: ProofQualityResponseCopy.tooVagueBody,
        footer: ProofQualityResponseCopy.footer,
        rows: ProofQualityResponseCopy.tooVagueRows,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        deltaLine: null,
        returnedAfterCorrectionLine:
            ProofQualityResponseCopy.returnedAfterCorrectionLine,
        stillTooVagueFollowUp: false,
      );

      expect(
        ProofQualityResponseEngine.shouldShow(
          result: result,
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

    test('hidden while recording', () {
      final result = ProofQualityResponseResult(
        shouldShow: true,
        feedbackState: ProofQualityFeedbackState.tooVague,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        proofKey: '1|2|3',
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasSafeAnchor: false,
        hasFreshReturn: false,
        title: ProofQualityResponseCopy.tooVagueTitle,
        body: ProofQualityResponseCopy.tooVagueBody,
        footer: ProofQualityResponseCopy.footer,
        rows: ProofQualityResponseCopy.tooVagueRows,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: true,
        deltaLine: null,
        returnedAfterCorrectionLine:
            ProofQualityResponseCopy.returnedAfterCorrectionLine,
        stillTooVagueFollowUp: false,
      );

      expect(
        ProofQualityResponseEngine.shouldShow(
          result: result,
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

    test('hidden during WhatChanged', () {
      final result = ProofQualityResponseResult(
        shouldShow: true,
        feedbackState: ProofQualityFeedbackState.alreadyKnewThis,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        proofKey: '1|2|3',
        entryCount: 3,
        source: 'test',
        hasConfirmedRepeat: true,
        hasSafeAnchor: false,
        hasFreshReturn: false,
        title: ProofQualityResponseCopy.alreadyKnewTitle,
        body: ProofQualityResponseCopy.alreadyKnewBody,
        footer: ProofQualityResponseCopy.footer,
        rows: ProofQualityResponseCopy.alreadyKnewRows,
        evidenceAnchors: const [],
        usesFallbackEvidenceLine: false,
        deltaLine: ProofQualityResponseCopy.alreadyKnewDeltaLine,
        returnedAfterCorrectionLine:
            ProofQualityResponseCopy.returnedAfterCorrectionLine,
        stillTooVagueFollowUp: false,
      );

      expect(
        ProofQualityResponseEngine.shouldShow(
          result: result,
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
  });

  group('ProofQualityResponseCard safety', () {
    testWidgets('no transcript/body/private text or Pro CTA', (tester) async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.tooVague);
      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );

      await _pumpCard(tester, result);

      expect(find.textContaining(_strongRepeat), findsNothing);
      expect(find.textContaining('See Pro'), findsNothing);
      expect(find.textContaining('therapy'), findsNothing);
    });
  });

  group('Downstream integration', () {
    Future<ProofQualityResponseResult> notRelevantResult(
      List<JournalEntry> entries,
    ) async {
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.notRelevant);
      return ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
    }

    test('PresentDayRelevance uses correction state', () async {
      final entries = _threeRelatedEntries();
      final result = await notRelevantResult(entries);
      await ProofQualityResponseEngine.applyNotRelevantAction(
        result: result,
        action: ProofQualityNotRelevantAction.keepAsBackground,
        source: 'test',
        store: ProofQualityResponseStore.forPrefs(prefs),
      );

      final present = PresentDayRelevanceEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
      );
      expect(present?.relevanceState, PresentDayRelevanceState.fading);
    });

    test('EvidenceWeighting uses correction state', () async {
      final entries = _threeRelatedEntries();
      final result = await notRelevantResult(entries);
      await ProofQualityResponseEngine.applyNotRelevantAction(
        result: result,
        action: ProofQualityNotRelevantAction.keepAsBackground,
        source: 'test',
        store: ProofQualityResponseStore.forPrefs(prefs),
      );

      final weighting = EvidenceWeightingEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(weighting?.primaryState, EvidenceWeightState.fading);
    });

    test('TimelineProofMoment shows correction row', () async {
      final entries = _threeRelatedEntries();
      final result = await notRelevantResult(entries);
      await ProofQualityResponseEngine.applyNotRelevantAction(
        result: result,
        action: ProofQualityNotRelevantAction.keepAsBackground,
        source: 'test',
        store: ProofQualityResponseStore.forPrefs(prefs),
      );

      final moment = TimelineProofMomentEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(moment?.hasCorrection, isTrue);
    });
  });

  group('SurfacePriorityAudit', () {
    test('allows only one detail correction response card', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 4,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: false,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
          betaTesterReport: false,
          correctionMemory: true,
          notRelevantRecovery: true,
          proofQualityResponse: true,
          patternConfidence: false,
          evidenceWeighting: false,
          currentRelevance: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          timelinePositioning: false,
          proEvidenceValue: false,
          archiveIntelligenceProBridge: false,
          privateReportProBridge: false,
          archiveBackupBridge: false,
          suppressLegacyEducation: false,
        ),
      );

      expect(
        result.correctionSlot,
        SurfacePriorityCardKey.proofQualityResponse,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.notRelevantRecovery,
          candidate: true,
        ),
        isFalse,
      );
    });
  });

  group('ProofQualityResponseAnalytics', () {
    testWidgets('metadata-only analytics', (tester) async {
      final entries = _threeRelatedEntries();
      await _saveBetaFeedback(prefs, BetaProofFeedbackType.notRelevant);
      final result = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      final store = ProofQualityResponseStore.forPrefs(prefs);

      await _pumpCard(tester, result, store: store);
      await tester.tap(
        find.byKey(const Key('proof_quality_response_keep_as_background')),
      );
      await tester.pumpAndSettle();

      expect(analyticsEvents.length, 2);
      for (final event in analyticsEvents) {
        expect(event.props.containsKey('entry_count'), isTrue);
        expect(event.props.containsKey('feedback_state'), isTrue);
        expect(event.props.containsKey('has_safe_anchor'), isTrue);
        expect(event.props.containsKey('has_confirmed_repeat'), isTrue);
        expect(
          event.props.keys.any((key) => key.contains('transcript')),
          isFalse,
        );
      }
      expect(analyticsEvents.last.props['answer_type'], 'keep_as_background');
    });
  });
}
