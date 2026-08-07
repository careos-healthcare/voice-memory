import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_analytics.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_copy.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_engine.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_model.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_strengthening_engine.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_store.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/return_after_proof_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(
        file: File('test/tmp/return_after_proof_strengthening/unused.json'),
      );

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

ReturnAfterProofResult _resultFor(
  List<JournalEntry> entries, {
  bool firstProofSeen = true,
  bool timelineProofVisible = false,
}) => ReturnAfterProofEngine.build(
  entries: entries,
  source: 'test',
  firstProofSeen: firstProofSeen,
  timelineProofVisible: timelineProofVisible,
  betaTesterReportVisible: false,
);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  String? selectedPrompt;

  setUp(() async {
    ArchiveBetaMissionGate.enabledOverride = true;
    ReturnAfterProofAnalytics.resetForTest();
    ReturnAfterProofAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    selectedPrompt = null;
    await ReturnAfterProofStore.resetForTest(_MemoryPrefs());
  });

  tearDown(() {
    ReturnAfterProofAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
  });

  group('ReturnAfterProofStrengtheningEngine', () {
    test('hidden before proof', () {
      final entries = _threeRelatedEntries();
      final strengthened = ReturnAfterProofStrengtheningEngine.build(
        entries: entries,
        source: 'test',
        firstProofSeen: false,
        timelineProofVisible: false,
      );
      expect(strengthened.shouldShow, isFalse);
      expect(
        ReturnAfterProofStrengtheningEngine.shouldShowOnRecordReady(
          result: strengthened,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          firstProofSeen: false,
          timelineProofVisible: false,
          dismissedForToday: false,
        ),
        isFalse,
      );
    });

    test('hidden when proof confidence is watchOnly or emerging', () {
      final weakEntries = [
        _entry('1', 'Had a normal day.'),
        _entry('2', 'Walk after lunch.'),
        _entry('3', 'Coffee in the morning.'),
      ];
      final watchOnly = ReturnAfterProofStrengtheningEngine.build(
        entries: weakEntries,
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: false,
      );
      expect(watchOnly.shouldShow, isFalse);

      final emerging = ReturnAfterProofStrengtheningEngine.build(
        entries: weakEntries,
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: false,
        calibration: const ProofConfidenceCalibrationResult(
          shouldCalibrate: true,
          entryCount: 3,
          source: 'test',
          level: ProofConfidenceLevel.emerging,
          primaryCopy: '',
          displayCopy: '',
          hasSafeAnchor: false,
          hasMatchQuality: true,
          hasCorrection: false,
          hasFreshReturn: false,
        ),
      );
      expect(emerging.shouldShow, isFalse);
    });

    test('visible when useful proof exists', () {
      final result = ReturnAfterProofStrengtheningEngine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: false,
      );
      expect(result.shouldShow, isTrue);
      expect(
        result.confidenceLevel,
        anyOf(ProofConfidenceLevel.useful, ProofConfidenceLevel.strong),
      );
    });

    test('visible when strong proof exists', () {
      final result = ReturnAfterProofStrengtheningEngine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: true,
      );
      expect(result.shouldShow, isTrue);
    });

    test('picks repeat watch target', () {
      final target =
          ReturnAfterProofStrengtheningEngine.resolveWatchTargetForTest(
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
            anchorTypes: const [EvidenceAnchorType.repeat],
          );
      expect(target, ReturnAfterProofWatchTargetType.returnedAgain);
      expect(
        ReturnAfterProofCopy.bodyForWatchTarget(target),
        ReturnAfterProofCopy.repeatWatchBody,
      );
    });

    test('picks softening watch target', () {
      final target =
          ReturnAfterProofStrengtheningEngine.resolveWatchTargetForTest(
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
            anchorTypes: const [EvidenceAnchorType.softening],
          );
      expect(target, ReturnAfterProofWatchTargetType.feltLighter);
    });

    test('picks strengthening watch target', () {
      final target =
          ReturnAfterProofStrengtheningEngine.resolveWatchTargetForTest(
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
            anchorTypes: const [EvidenceAnchorType.strengthening],
          );
      expect(target, ReturnAfterProofWatchTargetType.feltHeavier);
    });

    test('picks helped watch target', () {
      final target =
          ReturnAfterProofStrengtheningEngine.resolveWatchTargetForTest(
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
            anchorTypes: const [EvidenceAnchorType.helped],
          );
      expect(target, ReturnAfterProofWatchTargetType.helpedAgain);
    });

    test('picks corrected or fresh return watch target', () {
      final corrected =
          ReturnAfterProofStrengtheningEngine.resolveWatchTargetForTest(
            confidenceLevel: ProofConfidenceLevel.useful,
            hasSafeAnchor: true,
            anchorTypes: const [EvidenceAnchorType.corrected],
          );
      expect(corrected, ReturnAfterProofWatchTargetType.notCurrent);

      final freshReturn =
          ReturnAfterProofStrengtheningEngine.resolveWatchTargetForTest(
            confidenceLevel: ProofConfidenceLevel.freshReturn,
            hasSafeAnchor: true,
            anchorTypes: const [EvidenceAnchorType.repeat],
          );
      expect(freshReturn, ReturnAfterProofWatchTargetType.notCurrent);
    });

    test('fallback if no anchor', () {
      final result = ReturnAfterProofStrengtheningEngine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: false,
        calibration: const ProofConfidenceCalibrationResult(
          shouldCalibrate: true,
          entryCount: 3,
          source: 'test',
          level: ProofConfidenceLevel.useful,
          primaryCopy: '',
          displayCopy: '',
          hasSafeAnchor: false,
          hasMatchQuality: true,
          hasCorrection: false,
          hasFreshReturn: false,
        ),
      );
      if (!result.hasAnchor) {
        expect(result.body, ReturnAfterProofCopy.fallbackWatchBody);
      } else {
        expect(result.body, isNot(ReturnAfterProofCopy.fallbackWatchBody));
      }
    });

    test('hidden while recording, degraded, What Changed, or inbox active', () {
      final result = _resultFor(_threeRelatedEntries()).strengthened!;
      for (final override in [
        {'isRecording': true},
        {'isDegradedTranscriptState': true},
        {'whatChangedQuestionActive': true},
        {'patternReviewInboxHasActiveItems': true},
      ]) {
        expect(
          ReturnAfterProofStrengtheningEngine.shouldShowOnRecordReady(
            result: result,
            isReady: true,
            isRecording: override['isRecording'] ?? false,
            isDegradedTranscriptState:
                override['isDegradedTranscriptState'] ?? false,
            whatChangedQuestionActive:
                override['whatChangedQuestionActive'] ?? false,
            patternReviewInboxHasActiveItems:
                override['patternReviewInboxHasActiveItems'] ?? false,
            firstProofSeen: true,
            timelineProofVisible: false,
            dismissedForToday: false,
          ),
          isFalse,
        );
      }
    });

    test('hidden when dismissed today', () async {
      final result = _resultFor(_threeRelatedEntries()).strengthened!;
      await ReturnAfterProofStore.forPrefs(_MemoryPrefs()).dismissForDay();
      expect(
        ReturnAfterProofStrengtheningEngine.shouldShowOnRecordReady(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          firstProofSeen: true,
          timelineProofVisible: false,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        ),
        isFalse,
      );
    });

    test('generic card hidden when strengthened card is eligible', () {
      final result = _resultFor(_threeRelatedEntries());
      expect(
        ReturnAfterProofEngine.shouldShowGenericOnRecordReady(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          firstProofSeen: true,
          timelineProofVisible: false,
          betaTesterReportVisible: false,
          dismissedForToday: false,
        ),
        isFalse,
      );
      expect(
        ReturnAfterProofEngine.shouldShowStrengthenedOnRecordReady(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          firstProofSeen: true,
          timelineProofVisible: false,
          dismissedForToday: false,
        ),
        isTrue,
      );
    });
  });

  group('ReturnAfterProofAnalytics strengthened', () {
    test('metadata-only analytics payloads', () {
      final strengthened = ReturnAfterProofStrengtheningEngine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: true,
      );
      ReturnAfterProofAnalytics.strengthenedSeen(result: strengthened);
      ReturnAfterProofAnalytics.strengthenedCtaTapped(result: strengthened);
      ReturnAfterProofAnalytics.strengthenedDismissed(result: strengthened);

      expect(analyticsEvents.length, 3);
      for (final event in analyticsEvents) {
        expect(event.props.keys.toSet(), {
          'entry_count',
          'source',
          'target_type',
          'confidence_level',
          'has_anchor',
        });
      }
      expect(
        analyticsEvents[0].event,
        ReturnAfterProofAnalytics.strengthenedSeenEvent,
      );
      expect(
        analyticsEvents[1].event,
        ReturnAfterProofAnalytics.strengthenedCtaTappedEvent,
      );
      expect(
        analyticsEvents[2].event,
        ReturnAfterProofAnalytics.strengthenedDismissedEvent,
      );
    });
  });

  group('SurfacePriorityEngine strengthened', () {
    test(
      'returnAfterProofStrengthened beats generic and other guidance cards',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 5,
          source: 'record',
          candidates: SurfacePriorityCandidates.recordReady(
            firstMomentCapture: false,
            secondMomentReturn: false,
            returnAfterProofStrengthened: true,
            returnAfterProof: true,
            lowFrictionReturn: true,
            whatToNoticeNext: true,
            betaTodaySummary: false,
            openCapturePromptChips: false,
            captureFreedomLine: false,
            timelineProofMoment: true,
            archiveTimelineSpine: false,
            timelinePositioning: false,
            currentRelevance: false,
            correctionMemory: false,
            notRelevantRecovery: false,
            proofQualityResponse: false,
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
        expect(
          result.guidanceSlot,
          SurfacePriorityCardKey.returnAfterProofStrengthened,
        );
        expect(
          result.isVisible(
            SurfacePriorityCardKey.returnAfterProof,
            candidate: true,
          ),
          isFalse,
        );
        expect(result.visibleCardCount, greaterThan(0));
        expect(result.guidanceCardKey, 'returnAfterProofStrengthened');
      },
    );
  });

  group('ReturnAfterProofCard strengthened', () {
    testWidgets('CTA sets selected prompt line', (tester) async {
      final result = _resultFor(_threeRelatedEntries());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnAfterProofCard.test(
              result: result,
              useStrengthenedLayout: true,
              onPromptSelected: (prompt) => selectedPrompt = prompt,
              store: ReturnAfterProofStore.forPrefs(_MemoryPrefs()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(ReturnAfterProofCopy.strengthenedTitle), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('return_after_proof_strengthened_primary_cta')),
      );
      await tester.pump();

      expect(selectedPrompt, result.strengthened!.promptLine);
      expect(find.text(result.strengthened!.promptLine), findsOneWidget);
      expect(
        analyticsEvents.any(
          (event) =>
              event.event ==
              ReturnAfterProofAnalytics.strengthenedCtaTappedEvent,
        ),
        isTrue,
      );
    });

    testWidgets('Not today dismisses for today', (tester) async {
      final store = ReturnAfterProofStore.forPrefs(_MemoryPrefs());
      final result = _resultFor(_threeRelatedEntries());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnAfterProofCard.test(
              result: result,
              useStrengthenedLayout: true,
              onPromptSelected: (prompt) => selectedPrompt = prompt,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('return_after_proof_strengthened_secondary_cta')),
      );
      await tester.pumpAndSettle();

      expect(selectedPrompt, isNull);
      expect(ReturnAfterProofStore.isDismissedToday, isTrue);
      expect(
        analyticsEvents.any(
          (event) =>
              event.event ==
              ReturnAfterProofAnalytics.strengthenedDismissedEvent,
        ),
        isTrue,
      );
    });
  });

  group('ReturnAfterProofCopy strengthened safety', () {
    test('no notifications, streaks, or fake entries', () {
      for (final text in ReturnAfterProofCopy.allVisibleStrings()) {
        expect(text.toLowerCase(), isNot(contains('notification')));
        expect(text.toLowerCase(), isNot(contains('streak')));
      }
    });

    test('copy passes proof surface advice guard', () {
      for (final text in ReturnAfterProofCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });
}
