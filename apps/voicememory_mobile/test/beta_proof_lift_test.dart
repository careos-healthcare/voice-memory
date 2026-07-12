import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_analytics.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_copy.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_copy.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_engine.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/beta_proof_lift_card.dart';
import 'package:voicememory_mobile/widgets/patterns/timeline_proof_moment_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/beta_proof_lift/unused.json'));

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

BetaProofLiftResult _visibleResult({
  List<JournalEntry>? entries,
  BetaProofLiftSurface surface = BetaProofLiftSurface.timelineProofMoment,
}) {
  final journalEntries = entries ?? _threeRelatedEntries();
  final timeline = TimelineProofMomentEngine.build(
    entries: journalEntries,
    beliefSurfaceVisible: true,
    source: 'test',
    now: _now,
  );
  return BetaProofLiftEngine.build(
    entries: journalEntries,
    surface: surface,
    source: 'test',
    beliefSurfaceVisible: true,
    timelineProof: timeline,
    now: _now,
  );
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaProofLiftAnalytics.resetForTest();
    BetaProofLiftAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await BetaProofFeedbackStore.resetForTest(_MemoryPrefs());
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaProofLiftAnalytics.resetForTest();
  });

  group('BetaProofLiftCopy', () {
    test('all visible strings stay safe', () {
      for (final text in BetaProofLiftCopy.allVisibleStrings) {
        expect(BetaProofLiftCopy.isSafeCopy(text), isTrue);
      }
    });

    test('no therapy or medical claims', () {
      for (final text in BetaProofLiftCopy.allVisibleStrings) {
        final lower = text.toLowerCase();
        expect(lower, isNot(contains('therapy')));
        expect(lower, isNot(contains('diagnosis')));
        expect(lower, isNot(contains('medical treatment')));
      }
    });
  });

  group('BetaProofLiftEngine', () {
    test('renders all four sections and fallback copy', () {
      final result = _visibleResult(
        entries: [
          _entry('a', 'short one', createdAt: _now.subtract(const Duration(days: 10))),
          _entry('b', 'short two', createdAt: _now.subtract(const Duration(days: 9))),
          _entry('c', 'short three', createdAt: _now.subtract(const Duration(days: 8))),
        ],
      );
      expect(result.title, BetaProofLiftCopy.title);
      if (result.isWatchOnly) {
        expect(result.body, ProofConfidenceCalibrationCopy.watchOnlySubtitle);
        expect(
          result.sections.first.body,
          result.proofConfidenceCalibration.primaryCopy,
        );
      } else {
        expect(result.body, contains('This is not a label'));
        expect(result.sections.first.body, BetaProofLiftCopy.fallbackWhatRepeated);
      }
      expect(result.hasSafeAnchor, isFalse);
      expect(result.sections.length, 4);
      expect(
        result.sections.map((section) => section.heading).toList(),
        [
          BetaProofLiftCopy.sectionWhatRepeated,
          BetaProofLiftCopy.sectionWhatChanged,
          BetaProofLiftCopy.sectionWhyItMattersNow,
          BetaProofLiftCopy.sectionYourCorrection,
        ],
      );
    });

    test('renders delta rows when safe signals exist', () {
      final entries = _threeRelatedEntries();
      final result = _visibleResult(entries: entries);
      expect(result.hasDelta, isTrue);
      expect(result.deltaRows, isNotEmpty);
      expect(result.deltaRows, contains(BetaProofLiftCopy.deltaFeelsStronger));
    });

    test('shareable copy never includes transcript or entry ids', () {
      final result = _visibleResult();
      for (final text in result.allCopyStrings) {
        expect(text.toLowerCase(), isNot(contains('transcript')));
        expect(text.toLowerCase(), isNot(contains('entry_id')));
        expect(text, isNot(contains('Maria said')));
        expect(text, isNot(contains('concreteObservation')));
      }
    });

    test('hidden when beta flag disabled', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      final result = _visibleResult();
      final quality = ProofQualityResponseEngine.build(
        entries: _threeRelatedEntries(),
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      expect(
        BetaProofLiftEngine.shouldRender(
          result: result,
          qualityResponse: quality,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden while recording, degraded, What Changed, or inbox active', () {
      final result = _visibleResult();
      final quality = ProofQualityResponseEngine.build(
        entries: _threeRelatedEntries(),
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      for (final override in [
        {'isRecording': true},
        {'isDegradedTranscriptState': true},
        {'whatChangedQuestionActive': true},
        {'patternReviewInboxHasActiveItems': true},
      ]) {
        expect(
          BetaProofLiftEngine.shouldRender(
            result: result,
            qualityResponse: quality,
            parentVisible: true,
            timelineProofVisible: true,
            firstProofPayoffVisible: false,
            isRecording: override['isRecording'] as bool? ?? false,
            isDegradedTranscriptState:
                override['isDegradedTranscriptState'] as bool? ?? false,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive:
                override['whatChangedQuestionActive'] as bool? ?? false,
            patternReviewInboxHasActiveItems:
                override['patternReviewInboxHasActiveItems'] as bool? ?? false,
          ),
          isFalse,
        );
      }
    });

    test('visible under timeline proof before feedback', () {
      final entries = _threeRelatedEntries();
      final result = _visibleResult(entries: entries);
      final quality = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      expect(
        BetaProofLiftEngine.shouldRender(
          result: result,
          qualityResponse: quality,
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

    test('suppressed under first proof payoff with fewer than 3 entries', () {
      final entries = [_entry('1', _strongRepeat)];
      final result = BetaProofLiftEngine.build(
        entries: entries,
        surface: BetaProofLiftSurface.firstProofPayoff,
        source: 'test',
        beliefSurfaceVisible: true,
      );
      final quality = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.firstProofPayoff,
        source: 'test',
      );
      expect(
        BetaProofLiftEngine.shouldRender(
          result: result,
          qualityResponse: quality,
          parentVisible: true,
          timelineProofVisible: false,
          firstProofPayoffVisible: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('ProofQualityResponse wins when feedback already exists', () async {
      final entries = _threeRelatedEntries();
      final store = BetaProofFeedbackStore.forPrefs(_MemoryPrefs());
      await store.saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.tooVague,
        entryCount: entries.length,
      );
      final result = _visibleResult(entries: entries);
      final quality = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
      );
      expect(
        BetaProofLiftEngine.shouldRender(
          result: result,
          qualityResponse: quality,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
      expect(
        ProofQualityResponseEngine.shouldRender(
          result: quality,
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

    test('covers legacy boost when lift renders', () {
      final result = _visibleResult();
      expect(
        BetaProofLiftEngine.coversLegacyBoost(
          result: result,
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
  });

  group('BetaProofLiftAnalytics', () {
    test('metadata-only analytics payloads', () {
      final result = _visibleResult();
      BetaProofLiftAnalytics.seen(
        source: 'record',
        surface: 'record_ready',
        result: result,
      );
      expect(analyticsEvents.length, 1);
      expect(analyticsEvents.first.event, BetaProofLiftAnalytics.seenEvent);
      expect(analyticsEvents.first.props.keys.toSet(), {
        'entry_count',
        'source',
        'surface',
        'has_safe_anchor',
        'has_delta',
        'has_current_relevance',
        'has_correction',
      });
    });
  });

  group('SurfacePriorityEngine', () {
    test('proofQualityResponse wins over betaProofLift in correction slot', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: true,
          betaProofLift: true,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );
      expect(result.correctionSlot, SurfacePriorityCardKey.proofQualityResponse);
      expect(result.isVisible(SurfacePriorityCardKey.betaProofLift, candidate: true), isFalse);
    });

    test('betaProofLift can win when no proof quality response', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: true,
          proofQualityResponse: false,
          betaProofLift: true,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
        ),
      );
      expect(result.correctionSlot, SurfacePriorityCardKey.betaProofLift);
      expect(result.isVisible(SurfacePriorityCardKey.notRelevantRecovery, candidate: true), isFalse);
    });
  });

  group('BetaProofLiftCard', () {
    testWidgets('renders title and body when proof lift is visible', (tester) async {
      final entries = _threeRelatedEntries();
      final built = _visibleResult(entries: entries);
      final lift = BetaProofLiftResult(
        shouldShow: true,
        entryCount: built.entryCount,
        source: built.source,
        surface: built.surface,
        title: BetaProofLiftCopy.title,
        body: built.body,
        sections: built.sections,
        deltaRows: built.deltaRows,
        hasSafeAnchor: built.hasSafeAnchor,
        hasDelta: built.hasDelta,
        hasCurrentRelevance: built.hasCurrentRelevance,
        hasCorrection: built.hasCorrection,
        patternMatchQuality: built.patternMatchQuality,
        proofConfidenceCalibration: built.proofConfidenceCalibration,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BetaProofLiftCard(
              result: lift,
              source: 'record',
              surface: 'record_ready',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(BetaProofLiftCopy.title), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('beta_proof_lift_body'))).data,
        lift.body,
      );
      expect(find.text(BetaProofLiftCopy.sectionWhatRepeated), findsOneWidget);
      expect(find.text(BetaProofLiftCopy.sectionWhatChanged), findsOneWidget);
      expect(find.text(BetaProofLiftCopy.sectionWhyItMattersNow), findsOneWidget);
      expect(find.text(BetaProofLiftCopy.sectionYourCorrection), findsOneWidget);
    });
  });
}
