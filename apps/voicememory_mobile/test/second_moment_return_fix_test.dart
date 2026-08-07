import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/second_moment_return/second_moment_return_analytics.dart';
import 'package:voicememory_mobile/features/second_moment_return/second_moment_return_copy.dart';
import 'package:voicememory_mobile/features/second_moment_return/second_moment_return_engine.dart';
import 'package:voicememory_mobile/features/second_moment_return/second_moment_return_model.dart';
import 'package:voicememory_mobile/features/second_moment_return/second_moment_return_store.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/record/second_moment_return_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/second_moment_return/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(String id, {DateTime? createdAt}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? _now,
  transcript: 'Something from today that felt worth saving.',
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up today.',
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

SecondMomentReturnResult _buildResult({
  List<JournalEntry> entries = const [],
}) =>
    SecondMomentReturnEngine.build(entries: entries, source: 'test', now: _now);

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    SecondMomentReturnAnalytics.resetForTest();
    SecondMomentReturnAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await SecondMomentReturnStore.resetForTest(_MemoryPrefs());
  });

  tearDown(SecondMomentReturnAnalytics.resetForTest);

  group('SecondMomentReturnEngine', () {
    test('one-entry user sees card', () {
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(entries: [_entry('1')]),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          entryCount: 1,
        ),
        isTrue,
      );
    });

    test('zero-entry user does not see card', () {
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test('three-entry user does not see card by default', () {
      final entries = [
        _entry('1', createdAt: _now.subtract(const Duration(days: 2))),
        _entry('2', createdAt: _now.subtract(const Duration(days: 1))),
        _entry('3'),
      ];
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(entries: entries),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          entryCount: 3,
        ),
        isFalse,
      );
    });

    test('two entries without repeat may see card', () {
      final entries = [
        _entry('1', createdAt: _now.subtract(const Duration(days: 1))),
        _entry('2'),
      ];
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(entries: entries),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          entryCount: 2,
        ),
        isTrue,
      );
    });

    test('hidden during recording', () {
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(entries: [_entry('1')]),
          isReady: true,
          isRecording: true,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          entryCount: 1,
        ),
        isFalse,
      );
    });

    test('hidden post-save', () {
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(entries: [_entry('1')]),
          isReady: true,
          isRecording: false,
          isPostSave: true,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          entryCount: 1,
        ),
        isFalse,
      );
    });

    test('hidden degraded', () {
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(entries: [_entry('1')]),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: true,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
          entryCount: 1,
        ),
        isFalse,
      );
    });

    test('hidden during WhatChanged', () {
      expect(
        SecondMomentReturnEngine.shouldShow(
          result: _buildResult(entries: [_entry('1')]),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
          entryCount: 1,
        ),
        isFalse,
      );
    });

    test('no notifications requested', () {
      final source = File(
        'lib/features/second_moment_return/second_moment_return_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('notification')));
      expect(source, isNot(contains('push')));
    });

    test('no streak pressure', () {
      for (final line in SecondMomentReturnCopy.allVisibleStrings()) {
        expect(line.toLowerCase(), isNot(contains('streak')));
      }
    });

    test('no evidence classification changed', () {
      final source = File(
        'lib/features/second_moment_return/second_moment_return_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('evidenceweighting')));
      expect(source, isNot(contains('classif')));
    });

    test('no fake entry created', () {
      final source = File(
        'lib/features/second_moment_return/second_moment_return_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(source, isNot(contains('journalentry(')));
    });
  });

  group('SecondMomentReturnCard', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required VoidCallback onNoticedSomething,
      required ValueChanged<String> onPromptSelected,
      required VoidCallback onSaveOneSentence,
      SecondMomentReturnStore? store,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecondMomentReturnCard.test(
                result: _buildResult(entries: [_entry('1')]),
                onNoticedSomething: onNoticedSomething,
                onPromptSelected: onPromptSelected,
                onSaveOneSentence: onSaveOneSentence,
                store: store,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders One moment starts the archive', (tester) async {
      await pumpCard(
        tester,
        onNoticedSomething: () {},
        onPromptSelected: (_) {},
        onSaveOneSentence: () {},
      );
      expect(
        find.textContaining('One moment starts the archive'),
        findsOneWidget,
      );
    });

    testWidgets(
      'renders A second moment gives ArchiveMe something to compare',
      (tester) async {
        await pumpCard(
          tester,
          onNoticedSomething: () {},
          onPromptSelected: (_) {},
          onSaveOneSentence: () {},
        );
        expect(
          find.textContaining(
            'A second similar moment gives ArchiveMe something to compare',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders no daily pressure line', (tester) async {
      await pumpCard(
        tester,
        onNoticedSomething: () {},
        onPromptSelected: (_) {},
        onSaveOneSentence: () {},
      );
      expect(find.text(SecondMomentReturnCopy.noPressureLine), findsOneWidget);
    });

    testWidgets('I noticed something sets safe selected prompt line', (
      tester,
    ) async {
      var saveTapped = false;
      await pumpCard(
        tester,
        onNoticedSomething: () {},
        onPromptSelected: (_) {},
        onSaveOneSentence: () => saveTapped = true,
      );
      await tester.tap(
        find.byKey(const Key('second_moment_return_noticed_something')),
      );
      await tester.pump();
      expect(
        find.text(SecondMomentReturnCopy.afterNoticedSomething),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('second_moment_return_save_one_sentence')),
      );
      await tester.pump();
      expect(saveTapped, isTrue);
    });

    testWidgets('Show me what to notice expands prompts', (tester) async {
      await pumpCard(
        tester,
        onNoticedSomething: () {},
        onPromptSelected: (_) {},
        onSaveOneSentence: () {},
      );
      await tester.tap(
        find.byKey(const Key('second_moment_return_show_what_to_notice')),
      );
      await tester.pump();
      for (final type in SecondMomentReturnCopy.promptOrder) {
        expect(
          find.text(SecondMomentReturnCopy.promptTextFor(type)),
          findsOneWidget,
        );
      }
    });

    testWidgets('Not today dismisses for today', (tester) async {
      final prefs = _MemoryPrefs();
      await pumpCard(
        tester,
        onNoticedSomething: () {},
        onPromptSelected: (_) {},
        onSaveOneSentence: () {},
        store: SecondMomentReturnStore.forPrefs(prefs),
      );
      await tester.tap(find.byKey(const Key('second_moment_return_not_today')));
      await tester.pumpAndSettle();
      expect(find.text(SecondMomentReturnCopy.afterNotToday), findsOneWidget);
      expect(SecondMomentReturnStore.isDismissedToday, isTrue);
    });

    testWidgets('prompt tap sets selected prompt line', (tester) async {
      String? selected;
      await pumpCard(
        tester,
        onNoticedSomething: () {},
        onPromptSelected: (prompt) => selected = prompt,
        onSaveOneSentence: () {},
      );
      await tester.tap(
        find.byKey(const Key('second_moment_return_show_what_to_notice')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('second_moment_return_prompt_didThisComeBack')),
      );
      await tester.pump();
      expect(selected, SecondMomentReturnCopy.didThisComeBackPrompt);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(
        tester,
        onNoticedSomething: () {},
        onPromptSelected: (_) {},
        onSaveOneSentence: () {},
      );
      await tester.tap(
        find.byKey(const Key('second_moment_return_noticed_something')),
      );
      await tester.pump();

      expect(analyticsEvents, isNotEmpty);
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == SecondMomentReturnAnalytics.seenEvent,
      );
      expect(
        seen.props.keys,
        containsAll(['source', 'entry_count', 'has_confirmed_repeat']),
      );
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('body')));

      final tapped = analyticsEvents.firstWhere(
        (event) => event.event == SecondMomentReturnAnalytics.actionTappedEvent,
      );
      expect(tapped.props['action_type'], 'noticedSomething');
    });
  });

  group('Second moment return copy guard', () {
    test('no therapy/medical copy', () {
      for (final line in SecondMomentReturnCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });
  });

  group('Second moment return placement', () {
    test('appears below capture controls and above low friction return', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      final captureIndex = source.indexOf('_buildCaptureEntryActions');
      final cardIndex = source.indexOf(
        'if (showSecondMomentReturnCard && !firstUseSimplifiedRecord)',
      );
      final lowFrictionIndex = source.indexOf(
        'if (showLowFrictionReturnCard && !firstUseSimplifiedRecord)',
      );
      expect(cardIndex, greaterThan(captureIndex));
      expect(cardIndex, lessThan(lowFrictionIndex));
    });

    test(
      'SurfacePriorityAudit prefers three moment completion for exactly one entry',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 1,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            threeMomentCompletion: true,
            firstMomentCapture: false,
            secondMomentReturn: true,
            lowFrictionReturn: true,
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
          ),
        );
        expect(
          result.guidanceSlot,
          SurfacePriorityCardKey.threeMomentCompletion,
        );
        expect(
          result.isVisible(
            SurfacePriorityCardKey.secondMomentReturn,
            candidate: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'second moment return still wins when three moment completion inactive',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 1,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            threeMomentCompletion: false,
            firstMomentCapture: false,
            secondMomentReturn: true,
            lowFrictionReturn: true,
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
          ),
        );
        expect(result.guidanceSlot, SurfacePriorityCardKey.secondMomentReturn);
      },
    );
  });
}
