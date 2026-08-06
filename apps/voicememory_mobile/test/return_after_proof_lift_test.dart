import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_analytics.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_copy.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_engine.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_model.dart';
import 'package:voicememory_mobile/features/return_after_proof/return_after_proof_store.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/return_after_proof_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/return_after_proof/unused.json'));

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
  bool betaTesterReportVisible = false,
}) => ReturnAfterProofEngine.build(
  entries: entries,
  source: 'test',
  firstProofSeen: firstProofSeen,
  timelineProofVisible: timelineProofVisible,
  betaTesterReportVisible: betaTesterReportVisible,
);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  String? selectedPrompt;

  setUp(() async {
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

  group('ReturnAfterProofCopy', () {
    test('all visible strings stay safe and non-clinical', () {
      for (final text in ReturnAfterProofCopy.allVisibleStrings()) {
        expect(text.toLowerCase(), isNot(contains('therapy')));
        expect(text.toLowerCase(), isNot(contains('diagnosis')));
        expect(text.toLowerCase(), isNot(contains('notification')));
        expect(text.toLowerCase(), isNot(contains('streak')));
      }
    });
  });

  group('ReturnAfterProofEngine', () {
    test('hidden before first proof with fewer than 3 entries', () {
      final entries = [_entry('1', _strongRepeat)];
      final result = _resultFor(
        entries,
        firstProofSeen: false,
        timelineProofVisible: false,
        betaTesterReportVisible: false,
      );
      expect(
        ReturnAfterProofEngine.shouldShowOnRecordReady(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          firstProofSeen: false,
          timelineProofVisible: false,
          betaTesterReportVisible: false,
          dismissedForToday: false,
        ),
        isFalse,
      );
    });

    test('visible after first proof with 3 entries', () {
      final entries = _threeRelatedEntries();
      expect(FirstProofPayoffEngine.build(entries: entries), isNotNull);
      final result = _resultFor(entries, firstProofSeen: true);
      expect(
        ReturnAfterProofEngine.shouldShowOnRecordReady(
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
        isTrue,
      );
    });

    test('visible after TimelineProofMoment trigger', () {
      final entries = _threeRelatedEntries();
      final timeline = TimelineProofMomentEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(timeline, isNotNull);
      final result = _resultFor(
        entries,
        firstProofSeen: false,
        timelineProofVisible: true,
      );
      expect(
        ReturnAfterProofEngine.shouldShowOnRecordReady(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          firstProofSeen: false,
          timelineProofVisible: true,
          betaTesterReportVisible: false,
          dismissedForToday: false,
        ),
        isTrue,
      );
    });

    test('hidden while recording, degraded, What Changed, or inbox active', () {
      final entries = _threeRelatedEntries();
      final result = _resultFor(entries);
      for (final override in [
        {'isRecording': true},
        {'isDegradedTranscriptState': true},
        {'whatChangedQuestionActive': true},
        {'patternReviewInboxHasActiveItems': true},
      ]) {
        expect(
          ReturnAfterProofEngine.shouldShowOnRecordReady(
            result: result,
            isReady: true,
            isRecording: override['isRecording'] as bool? ?? false,
            isDegradedTranscriptState:
                override['isDegradedTranscriptState'] as bool? ?? false,
            whatChangedQuestionActive:
                override['whatChangedQuestionActive'] as bool? ?? false,
            patternReviewInboxHasActiveItems:
                override['patternReviewInboxHasActiveItems'] as bool? ?? false,
            firstProofSeen: true,
            timelineProofVisible: false,
            betaTesterReportVisible: false,
            dismissedForToday: false,
          ),
          isFalse,
        );
      }
    });

    test('hidden when dismissed today', () async {
      final entries = _threeRelatedEntries();
      final result = _resultFor(entries);
      await ReturnAfterProofStore.forPrefs(_MemoryPrefs()).dismissForDay();
      expect(
        ReturnAfterProofEngine.shouldShowOnRecordReady(
          result: result,
          isReady: true,
          isRecording: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          firstProofSeen: true,
          timelineProofVisible: false,
          betaTesterReportVisible: false,
          dismissedForToday: ReturnAfterProofStore.isDismissedToday,
        ),
        isFalse,
      );
    });

    test('visible on first proof post-save', () {
      final entries = _threeRelatedEntries();
      final result = _resultFor(entries);
      expect(
        ReturnAfterProofEngine.shouldShowOnFirstProofPayoffPostSave(
          result: result,
          showFirstProofPayoff: true,
          isRecording: false,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          dismissedForToday: false,
        ),
        isTrue,
      );
    });
  });

  group('ReturnAfterProofAnalytics', () {
    test('metadata-only analytics payloads', () {
      final result = _resultFor(
        _threeRelatedEntries(),
        timelineProofVisible: true,
      );
      ReturnAfterProofAnalytics.seen(result: result);
      ReturnAfterProofAnalytics.promptTapped(
        result: result,
        promptType: ReturnAfterProofPromptType.itCameBack,
      );
      ReturnAfterProofAnalytics.dismissedToday(result: result);

      expect(analyticsEvents.length, 3);
      expect(analyticsEvents[0].props.keys.toSet(), {
        'entry_count',
        'source',
        'has_timeline_proof',
        'has_first_proof',
      });
      expect(analyticsEvents[1].props.keys.toSet(), {
        'entry_count',
        'source',
        'has_timeline_proof',
        'has_first_proof',
        'prompt_type',
      });
      expect(analyticsEvents[0].event, ReturnAfterProofAnalytics.seenEvent);
      expect(
        analyticsEvents[1].event,
        ReturnAfterProofAnalytics.promptTappedEvent,
      );
      expect(
        analyticsEvents[2].event,
        ReturnAfterProofAnalytics.dismissedTodayEvent,
      );
    });
  });

  group('SurfacePriorityEngine', () {
    test('returnAfterProof beats lowFrictionReturn and whatToNoticeNext', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 5,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
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
      expect(result.guidanceSlot, SurfacePriorityCardKey.returnAfterProof);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.lowFrictionReturn,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.isVisible(
          SurfacePriorityCardKey.whatToNoticeNext,
          candidate: true,
        ),
        isFalse,
      );
    });

    test('returnAfterProofStrengthened beats generic returnAfterProof', () {
      ArchiveBetaMissionGate.enabledOverride = true;
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
    });
  });

  group('ReturnAfterProofCard', () {
    testWidgets('renders title, body, and all prompts', (tester) async {
      final result = _resultFor(_threeRelatedEntries());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReturnAfterProofCard.test(
                result: result,
                onPromptSelected: (prompt) => selectedPrompt = prompt,
                store: ReturnAfterProofStore.forPrefs(_MemoryPrefs()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(result.title), findsOneWidget);
      expect(find.text(result.body), findsOneWidget);
      for (final type in ReturnAfterProofPromptTypeLists.capturePrompts) {
        expect(
          find.text(ReturnAfterProofCopy.chipLabelFor(type)),
          findsOneWidget,
        );
      }
    });

    testWidgets('tapping prompt sets selected prompt line only', (
      tester,
    ) async {
      final result = _resultFor(_threeRelatedEntries());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnAfterProofCard.test(
              result: result,
              onPromptSelected: (prompt) => selectedPrompt = prompt,
              store: ReturnAfterProofStore.forPrefs(_MemoryPrefs()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('return_after_proof_prompt_itCameBack')),
      );
      await tester.pump();

      expect(selectedPrompt, 'This came back:');
      expect(find.text('This came back:'), findsOneWidget);
      expect(
        analyticsEvents.any(
          (event) => event.event == ReturnAfterProofAnalytics.promptTappedEvent,
        ),
        isTrue,
      );
    });

    testWidgets('Not today dismisses locally for today', (tester) async {
      final store = ReturnAfterProofStore.forPrefs(_MemoryPrefs());
      final result = _resultFor(_threeRelatedEntries());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnAfterProofCard.test(
              result: result,
              onPromptSelected: (prompt) => selectedPrompt = prompt,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('return_after_proof_prompt_notToday')),
      );
      await tester.pumpAndSettle();

      expect(selectedPrompt, isNull);
      expect(
        find.text(ReturnAfterProofCopy.afterNotTodayDismiss),
        findsOneWidget,
      );
      expect(ReturnAfterProofStore.isDismissedToday, isTrue);
      expect(
        analyticsEvents.any(
          (event) =>
              event.event == ReturnAfterProofAnalytics.dismissedTodayEvent,
        ),
        isTrue,
      );
    });

    test('copy passes proof surface advice guard', () {
      for (final text in ReturnAfterProofCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });
}
