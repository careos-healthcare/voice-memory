import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/first_moment_capture/first_moment_capture_analytics.dart';
import 'package:archiveme_mobile/features/first_moment_capture/first_moment_capture_copy.dart';
import 'package:archiveme_mobile/features/first_moment_capture/first_moment_capture_engine.dart';
import 'package:archiveme_mobile/features/first_moment_capture/first_moment_capture_model.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/widgets/record/first_moment_capture_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FirstMomentCaptureResult _buildResult({int entryCount = 0}) =>
    FirstMomentCaptureEngine.build(entryCount: entryCount, source: 'test');

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    FirstMomentCaptureAnalytics.resetForTest();
    FirstMomentCaptureAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(FirstMomentCaptureAnalytics.resetForTest);

  group('FirstMomentCaptureEngine', () {
    test('zero-entry user sees card', () {
      expect(
        FirstMomentCaptureEngine.shouldShow(
          result: _buildResult(),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isTrue,
      );
    });

    test('one-entry user does not see card', () {
      expect(
        FirstMomentCaptureEngine.shouldShow(
          result: _buildResult(entryCount: 1),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          isPermissionBlocked: false,
          entryCount: 1,
        ),
        isFalse,
      );
    });

    test('hidden during recording', () {
      expect(
        FirstMomentCaptureEngine.shouldShow(
          result: _buildResult(),
          isReady: true,
          isRecording: true,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test('hidden post-save', () {
      expect(
        FirstMomentCaptureEngine.shouldShow(
          result: _buildResult(),
          isReady: true,
          isRecording: false,
          isPostSave: true,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test('hidden degraded', () {
      expect(
        FirstMomentCaptureEngine.shouldShow(
          result: _buildResult(),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: true,
          firstProofPayoffVisible: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test('hidden when permission blocked', () {
      expect(
        FirstMomentCaptureEngine.shouldShow(
          result: _buildResult(),
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          firstProofPayoffVisible: false,
          isPermissionBlocked: true,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test('does not create fake entries', () {
      final engineSource = File(
        'lib/features/first_moment_capture/first_moment_capture_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(engineSource, isNot(contains('journalentry(')));
      expect(engineSource, isNot(contains('seed')));
    });

    test('does not classify examples as evidence', () {
      final engineSource = File(
        'lib/features/first_moment_capture/first_moment_capture_engine.dart',
      ).readAsStringSync().toLowerCase();
      expect(engineSource, isNot(contains('evidenceweighting')));
      expect(engineSource, isNot(contains('earlyfirstsignal')));
    });
  });

  group('FirstMomentCaptureCard', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required VoidCallback onSaveOneSentence,
      required VoidCallback onRecordInstead,
      required ValueChanged<String> onExampleSelected,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FirstMomentCaptureCard.test(
                result: _buildResult(),
                onSaveOneSentence: onSaveOneSentence,
                onRecordInstead: onRecordInstead,
                onExampleSelected: onExampleSelected,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders Start with one sentence', (tester) async {
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () {},
        onExampleSelected: (_) {},
      );
      expect(find.text(FirstMomentCaptureCopy.title), findsOneWidget);
    });

    testWidgets('renders Anything from today counts', (tester) async {
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () {},
        onExampleSelected: (_) {},
      );
      expect(find.textContaining('Anything from today counts'), findsOneWidget);
    });

    testWidgets('renders You do not need to know the pattern yet', (
      tester,
    ) async {
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () {},
        onExampleSelected: (_) {},
      );
      expect(find.text(FirstMomentCaptureCopy.reassurance), findsOneWidget);
    });

    testWidgets('renders privacy line', (tester) async {
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () {},
        onExampleSelected: (_) {},
      );
      expect(find.text(FirstMomentCaptureCopy.privacyLine), findsOneWidget);
    });

    testWidgets('renders all tiny examples', (tester) async {
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () {},
        onExampleSelected: (_) {},
      );
      for (final type in FirstMomentCaptureCopy.exampleOrder) {
        expect(
          find.text(FirstMomentCaptureCopy.exampleTextFor(type)),
          findsOneWidget,
        );
      }
    });

    testWidgets('save one sentence uses existing safe type flow', (
      tester,
    ) async {
      var saveTapped = false;
      await pumpCard(
        tester,
        onSaveOneSentence: () => saveTapped = true,
        onRecordInstead: () {},
        onExampleSelected: (_) {},
      );
      await tester.tap(
        find.byKey(const Key('first_moment_capture_save_one_sentence')),
      );
      await tester.pump();
      expect(saveTapped, isTrue);
    });

    testWidgets('record instead does not route away unexpectedly', (
      tester,
    ) async {
      var recordTapped = false;
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () => recordTapped = true,
        onExampleSelected: (_) {},
      );
      await tester.tap(
        find.byKey(const Key('first_moment_capture_record_instead')),
      );
      await tester.pump();
      expect(recordTapped, isTrue);
    });

    testWidgets('example tap sets selected prompt line', (tester) async {
      String? selected;
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () {},
        onExampleSelected: (prompt) => selected = prompt,
      );
      await tester.tap(
        find.byKey(const Key('first_moment_capture_example_keptPuttingOff')),
      );
      await tester.pump();
      expect(selected, FirstMomentCaptureCopy.keptPuttingOffExample);
    });

    testWidgets('metadata-only analytics', (tester) async {
      await pumpCard(
        tester,
        onSaveOneSentence: () {},
        onRecordInstead: () {},
        onExampleSelected: (_) {},
      );
      await tester.tap(
        find.byKey(const Key('first_moment_capture_save_one_sentence')),
      );
      await tester.pump();

      expect(analyticsEvents, isNotEmpty);
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == FirstMomentCaptureAnalytics.seenEvent,
      );
      expect(seen.props.keys, containsAll(['source', 'entry_count']));
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('body')));

      final tapped = analyticsEvents.firstWhere(
        (event) => event.event == FirstMomentCaptureAnalytics.ctaTappedEvent,
      );
      expect(tapped.props['action_type'], 'saveOneSentence');
    });
  });

  group('First moment capture copy guard', () {
    test('no therapy/medical copy', () {
      for (final line in FirstMomentCaptureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });

    test('no subscription CTA', () {
      for (final path in [
        'lib/features/first_moment_capture/first_moment_capture_copy.dart',
        'lib/widgets/record/first_moment_capture_card.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('subscribe')));
        expect(source, isNot(contains('revenuecat')));
      }
    });
  });

  group('First moment capture placement', () {
    test(
      'appears above other guidance cards on Record when not simplified',
      () {
        final source = readRecordScreenLibrarySource();
        final cardIndex = source.indexOf(
          'if (ctx.showFirstMomentCaptureCard &&\n'
          '            !ctx.firstUseSimplifiedRecord) ...[',
        );
        final openCaptureIndex = source.indexOf(
          'if (ctx.showOpenCapturePromptChips &&\n'
          '            !ctx.firstUseSimplifiedRecord &&\n'
          '            !ctx.showReturningWatchTargetFocusedUi) ...[',
        );
        final lowFrictionIndex = source.indexOf(
          'if (ctx.showLowFrictionReturnCard &&\n'
          '            !ctx.firstUseSimplifiedRecord &&\n'
          '            !ctx.showReturningWatchTargetFocusedUi &&\n'
          '            !ReturningRecordWatchTargetUiGates.watchPromptSkippedToday()) ...[',
        );
        expect(cardIndex, greaterThan(0));
        expect(cardIndex, lessThan(openCaptureIndex));
        expect(cardIndex, lessThan(lowFrictionIndex));
      },
    );

    test('uses navigateToTypeInsteadCapture for save one sentence', () {
      final source = readRecordScreenLibrarySource();
      expect(source, contains('navigateToTypeInsteadCapture'));
      expect(source, contains("source: 'first_moment_capture'"));
    });

    test(
      'SurfacePriorityAudit gives three moment completion highest guidance priority for zero entry',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 0,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            threeMomentCompletion: true,
            firstMomentCapture: true,
            secondMomentReturn: false,
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
            SurfacePriorityCardKey.firstMomentCapture,
            candidate: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'first moment capture still wins when three moment completion inactive',
      () {
        final result = SurfacePriorityEngine.auditRecordReady(
          entryCount: 0,
          source: 'test',
          candidates: SurfacePriorityCandidates.recordReady(
            firstMomentCapture: true,
            secondMomentReturn: false,
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
        expect(result.guidanceSlot, SurfacePriorityCardKey.firstMomentCapture);
      },
    );
  });
}