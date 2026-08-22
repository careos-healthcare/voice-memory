import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_model.dart';
import 'package:archiveme_mobile/features/return_after_proof_lift_v2/return_after_proof_lift_v2_analytics.dart';
import 'package:archiveme_mobile/features/return_after_proof_lift_v2/return_after_proof_lift_v2_copy.dart';
import 'package:archiveme_mobile/features/return_after_proof_lift_v2/return_after_proof_lift_v2_engine.dart';
import 'package:archiveme_mobile/features/return_after_proof_lift_v2/return_after_proof_lift_v2_store.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/record/return_after_proof_lift_v2_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/return_after_proof_lift_v2/unused.json'));

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

void main() {
  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    ReturnAfterProofLiftV2Analytics.resetForTest();
    await ReturnAfterProofLiftV2Store.resetForTest(_MemoryPrefs());
  });

  group('ReturnAfterProofLiftV2Copy', () {
    test('uses stronger return hook copy', () {
      expect(
        ReturnAfterProofLiftV2Copy.title,
        'Come back when it happens again',
      );
      expect(
        ReturnAfterProofLiftV2Copy.body,
        'The next save is what tells ArchiveMe whether this is getting louder, softer, or fading.',
      );
      expect(ReturnAfterProofLiftV2Copy.primaryCta, 'Save the next return');
      expect(
        ReturnAfterProofLiftV2Copy.watchLineFor(
          ReturnAfterProofWatchTargetType.returnedAgain,
        ),
        'Watch for the same situation returning.',
      );
      expect(
        ReturnAfterProofLiftV2Copy.fallbackWatchLine,
        'Watch for the next moment that feels connected.',
      );
    });
  });

  group('ReturnAfterProofLiftV2Engine', () {
    test('hidden when beta off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      final result = ReturnAfterProofLiftV2Engine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: true,
      );
      expect(result.shouldShow, isFalse);
    });

    test('visible after useful proof foundation', () {
      final result = ReturnAfterProofLiftV2Engine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: true,
      );
      expect(result.shouldShow, isTrue);
      expect(
        ReturnAfterProofLiftV2Engine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('hidden when dismissed for day', () async {
      await ReturnAfterProofLiftV2Store.dismissForDay();
      final result = ReturnAfterProofLiftV2Engine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: true,
      );
      expect(result.shouldShow, isFalse);
    });
  });

  group('ReturnAfterProofLiftV2Card', () {
    testWidgets('secondary expands watch line', (tester) async {
      final result = ReturnAfterProofLiftV2Engine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReturnAfterProofLiftV2Card.test(
              result: result,
              onPrimaryCta: () {},
              onPromptSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('return_after_proof_lift_v2_secondary_cta')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('return_after_proof_lift_v2_watch_line')),
        findsOneWidget,
      );
    });
  });

  group('ReturnAfterProofLiftV2Analytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      ReturnAfterProofLiftV2Analytics.captureForTest = (event, props) {
        events.add(event);
        expect(props.containsKey('source'), isTrue);
        expect(props.containsKey('entry_count'), isTrue);
        expect(props.containsKey('transcript'), isFalse);
      };

      final result = ReturnAfterProofLiftV2Engine.build(
        entries: _threeRelatedEntries(),
        source: 'test',
        firstProofSeen: true,
        timelineProofVisible: true,
      );
      ReturnAfterProofLiftV2Analytics.seen(result: result);
      ReturnAfterProofLiftV2Analytics.ctaTapped(
        result: result,
        actionType: ReturnAfterProofLiftV2ActionType.expandWatch,
      );

      expect(events, [
        ReturnAfterProofLiftV2Analytics.seenEvent,
        ReturnAfterProofLiftV2Analytics.expandedEvent,
      ]);
    });
  });

  group('SurfacePriorityEngine return lift v2', () {
    test('beats generic return-after-proof guidance slot', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 3,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          returnAfterProofLiftV2: true,
          returnAfterProof: true,
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: false,
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
        SurfacePriorityCardKey.returnAfterProofLiftV2,
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

  group('Integration placement', () {
    test('record screen integrates return lift v2 card', () {
      final source = readRecordScreenLibrarySource();
      expect(source, contains('ReturnAfterProofLiftV2Card'));
      expect(source, contains('returnAfterProofLiftV2'));
    });
  });
}