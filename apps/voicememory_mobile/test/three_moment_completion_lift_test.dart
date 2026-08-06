import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/three_moment_completion/three_moment_completion_analytics.dart';
import 'package:voicememory_mobile/features/three_moment_completion/three_moment_completion_copy.dart';
import 'package:voicememory_mobile/features/three_moment_completion/three_moment_completion_engine.dart';
import 'package:voicememory_mobile/features/three_moment_completion/three_moment_completion_model.dart';
import 'package:voicememory_mobile/features/three_moment_completion/three_moment_completion_store.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/three_moment_completion_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/three_moment_completion/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ThreeMomentCompletionResult _buildResult({int entryCount = 0}) =>
    ThreeMomentCompletionEngine.build(entryCount: entryCount, source: 'test');

Map<String, Object> _baseVisibility({
  bool isReady = true,
  bool isRecording = false,
  bool isPostSave = false,
  bool isDegradedTranscriptState = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool isPermissionBlocked = false,
  int entryCount = 0,
  bool dismissedForToday = false,
}) => {
  'isReady': isReady,
  'isRecording': isRecording,
  'isPostSave': isPostSave,
  'isDegradedTranscriptState': isDegradedTranscriptState,
  'whatChangedQuestionActive': whatChangedQuestionActive,
  'patternReviewInboxHasActiveItems': patternReviewInboxHasActiveItems,
  'isPermissionBlocked': isPermissionBlocked,
  'entryCount': entryCount,
  'dismissedForToday': dismissedForToday,
};

bool _shouldShow({
  required ThreeMomentCompletionResult result,
  required Map<String, Object> args,
}) => ThreeMomentCompletionEngine.shouldShow(
  result: result,
  isReady: args['isReady']! as bool,
  isRecording: args['isRecording']! as bool,
  isPostSave: args['isPostSave']! as bool,
  isDegradedTranscriptState: args['isDegradedTranscriptState']! as bool,
  whatChangedQuestionActive: args['whatChangedQuestionActive']! as bool,
  patternReviewInboxHasActiveItems:
      args['patternReviewInboxHasActiveItems']! as bool,
  isPermissionBlocked: args['isPermissionBlocked']! as bool,
  entryCount: args['entryCount']! as int,
  dismissedForToday: args['dismissedForToday']! as bool,
);

SurfacePriorityCandidates _earlyGuidanceCandidates({
  required bool threeMomentCompletion,
  bool firstMomentCapture = true,
  bool secondMomentReturn = true,
  bool lowFrictionReturn = true,
}) => SurfacePriorityCandidates.recordReady(
  threeMomentCompletion: threeMomentCompletion,
  firstMomentCapture: firstMomentCapture,
  secondMomentReturn: secondMomentReturn,
  lowFrictionReturn: lowFrictionReturn,
  whatToNoticeNext: true,
  betaTodaySummary: true,
  openCapturePromptChips: true,
  captureFreedomLine: true,
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
);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    ThreeMomentCompletionAnalytics.resetForTest();
    ThreeMomentCompletionAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await ThreeMomentCompletionStore.resetForTest(_MemoryPrefs());
  });

  tearDown(ThreeMomentCompletionAnalytics.resetForTest);

  group('ThreeMomentCompletionCopy', () {
    test('zero-entry shows start copy', () {
      final result = _buildResult();
      expect(result.title, ThreeMomentCompletionCopy.startTitle);
      expect(result.body, ThreeMomentCompletionCopy.startBody);
      expect(result.primaryCta, ThreeMomentCompletionCopy.startPrimaryCta);
      expect(result.stage, ThreeMomentCompletionStage.start);
    });

    test('one-entry shows second moment copy', () {
      final result = _buildResult(entryCount: 1);
      expect(result.title, ThreeMomentCompletionCopy.secondTitle);
      expect(result.body, ThreeMomentCompletionCopy.secondBody);
      expect(result.primaryCta, ThreeMomentCompletionCopy.secondPrimaryCta);
      expect(result.stage, ThreeMomentCompletionStage.second);
    });

    test('two-entry shows third moment copy', () {
      final result = _buildResult(entryCount: 2);
      expect(result.title, ThreeMomentCompletionCopy.thirdTitle);
      expect(result.body, ThreeMomentCompletionCopy.thirdBody);
      expect(result.primaryCta, ThreeMomentCompletionCopy.thirdPrimaryCta);
      expect(result.stage, ThreeMomentCompletionStage.third);
    });

    test('three-entry hides card', () {
      final result = _buildResult(entryCount: 3);
      expect(result.shouldShow, isFalse);
      expect(
        ThreeMomentCompletionEngine.shouldShow(
          result: result,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          isPermissionBlocked: false,
          entryCount: 3,
          dismissedForToday: false,
        ),
        isFalse,
      );
    });
  });

  group('ThreeMomentCompletionEngine visibility', () {
    test('hidden recording', () {
      expect(
        _shouldShow(
          result: _buildResult(),
          args: _baseVisibility(isRecording: true),
        ),
        isFalse,
      );
    });

    test('hidden post-save', () {
      expect(
        _shouldShow(
          result: _buildResult(),
          args: _baseVisibility(isPostSave: true),
        ),
        isFalse,
      );
    });

    test('hidden degraded', () {
      expect(
        _shouldShow(
          result: _buildResult(),
          args: _baseVisibility(isDegradedTranscriptState: true),
        ),
        isFalse,
      );
    });

    test('hidden during WhatChanged', () {
      expect(
        _shouldShow(
          result: _buildResult(entryCount: 1),
          args: _baseVisibility(entryCount: 1, whatChangedQuestionActive: true),
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox', () {
      expect(
        _shouldShow(
          result: _buildResult(entryCount: 2),
          args: _baseVisibility(
            entryCount: 2,
            patternReviewInboxHasActiveItems: true,
          ),
        ),
        isFalse,
      );
    });

    test('does not create fake entries', () {
      final engineSource = File(
        'lib/features/three_moment_completion/three_moment_completion_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(engineSource, isNot(contains('journalentry(')));
      expect(engineSource, isNot(contains('seed')));
    });

    test('does not change evidence classification', () {
      final engineSource = File(
        'lib/features/three_moment_completion/three_moment_completion_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(engineSource, isNot(contains('evidenceweighting')));
      expect(engineSource, isNot(contains('earlyfirstsignal')));
    });

    test('does not request notifications', () {
      for (final path in [
        'lib/features/three_moment_completion/three_moment_completion_engine.dart',
        'lib/widgets/record/three_moment_completion_card.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('notification')));
        expect(source, isNot(contains('push')));
      }
    });

    test('no streak pressure copy', () {
      for (final line in ThreeMomentCompletionCopy.allVisibleStrings()) {
        expect(line.toLowerCase(), isNot(contains('streak')));
        if (line != ThreeMomentCompletionCopy.noPressureLine) {
          expect(line.toLowerCase(), isNot(contains('daily journal')));
        }
      }
      expect(
        ThreeMomentCompletionCopy.noPressureLine,
        contains('No daily journal required'),
      );
    });

    test('no therapy/medical claims', () {
      for (final line in ThreeMomentCompletionCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });
  });

  group('ThreeMomentCompletionCard', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required ThreeMomentCompletionResult result,
      required VoidCallback onPrimaryCta,
      ThreeMomentCompletionStore? store,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThreeMomentCompletionCard.test(
                result: result,
                onPrimaryCta: onPrimaryCta,
                store: store,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('CTA uses existing capture flow callback', (tester) async {
      var tapped = false;
      await pumpCard(
        tester,
        result: _buildResult(),
        onPrimaryCta: () => tapped = true,
      );
      await tester.tap(
        find.byKey(const Key('three_moment_completion_primary_cta')),
      );
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('Not today dismisses locally', (tester) async {
      final prefs = _MemoryPrefs();
      final store = ThreeMomentCompletionStore.forPrefs(prefs);
      await pumpCard(
        tester,
        result: _buildResult(entryCount: 1),
        onPrimaryCta: () {},
        store: store,
      );
      await tester.tap(
        find.byKey(const Key('three_moment_completion_not_today')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('three_moment_completion_card')),
        findsNothing,
      );
      expect(ThreeMomentCompletionStore.isDismissedToday, isTrue);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(
        tester,
        result: _buildResult(entryCount: 2),
        onPrimaryCta: () {},
      );
      await tester.tap(
        find.byKey(const Key('three_moment_completion_primary_cta')),
      );
      await tester.pump();

      expect(analyticsEvents, isNotEmpty);
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == ThreeMomentCompletionAnalytics.seenEvent,
      );
      expect(seen.props.keys, containsAll(['source', 'entry_count', 'stage']));
      expect(seen.props.keys, isNot(contains('transcript')));

      final tapped = analyticsEvents.firstWhere(
        (event) => event.event == ThreeMomentCompletionAnalytics.ctaTappedEvent,
      );
      expect(tapped.props['action_type'], 'save_one_more_moment');
      expect(tapped.props['stage'], 'third');
    });
  });

  group('SurfacePriorityEngine guidance consolidation', () {
    test('suppresses FirstMomentCaptureCard when active', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 0,
        source: 'test',
        candidates: _earlyGuidanceCandidates(threeMomentCompletion: true),
      );
      expect(result.guidanceSlot, SurfacePriorityCardKey.threeMomentCompletion);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.firstMomentCapture,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.hiddenReasons,
        contains(SurfacePriorityCopy.hiddenReasonGuidanceCap),
      );
    });

    test('suppresses SecondMomentReturnCard when active', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 1,
        source: 'test',
        candidates: _earlyGuidanceCandidates(threeMomentCompletion: true),
      );
      expect(result.guidanceSlot, SurfacePriorityCardKey.threeMomentCompletion);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.secondMomentReturn,
          candidate: true,
        ),
        isFalse,
      );
    });

    test('suppresses generic low-friction card when active', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 2,
        source: 'test',
        candidates: _earlyGuidanceCandidates(threeMomentCompletion: true),
      );
      expect(result.guidanceSlot, SurfacePriorityCardKey.threeMomentCompletion);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.lowFrictionReturn,
          candidate: true,
        ),
        isFalse,
      );
    });

    test('allows max one guidance card', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 1,
        source: 'test',
        candidates: _earlyGuidanceCandidates(threeMomentCompletion: true),
      );
      final guidanceVisible = result.visibleCardKeys
          .where(
            (key) =>
                key == SurfacePriorityCardKey.threeMomentCompletion ||
                key == SurfacePriorityCardKey.firstMomentCapture ||
                key == SurfacePriorityCardKey.secondMomentReturn ||
                key == SurfacePriorityCardKey.lowFrictionReturn ||
                key == SurfacePriorityCardKey.whatToNoticeNext ||
                key == SurfacePriorityCardKey.betaTodaySummary ||
                key == SurfacePriorityCardKey.openCapturePromptChips ||
                key == SurfacePriorityCardKey.captureFreedomLine,
          )
          .length;
      expect(guidanceVisible, 1);
    });
  });

  group('Record screen integration', () {
    test('uses navigateToTypeInsteadCapture for primary CTA', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('ThreeMomentCompletionCard'));
      expect(source, contains('navigateToTypeInsteadCapture'));
    });
  });
}
