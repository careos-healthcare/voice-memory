import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/first_run_positioning/first_run_positioning_copy.dart';
import 'package:archiveme_mobile/features/first_run_positioning/first_run_positioning_engine.dart';
import 'package:archiveme_mobile/features/first_run_positioning/first_run_positioning_model.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/record/first_run_positioning_card.dart';
import 'package:archiveme_research/screens/testing_archiveme_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FirstRunPositioningResult _result({int entryCount = 0}) =>
    FirstRunPositioningEngine.build(entryCount: entryCount, source: 'test');

bool _shouldShow({
  required FirstRunPositioningResult result,
  int entryCount = 0,
  bool isReady = true,
  bool isRecording = false,
  bool isPostSave = false,
  bool isDegradedTranscriptState = false,
  bool firstProofSeen = false,
  bool isPermissionBlocked = false,
}) => FirstRunPositioningEngine.shouldShow(
  result: result,
  isReady: isReady,
  isRecording: isRecording,
  isPostSave: isPostSave,
  isDegradedTranscriptState: isDegradedTranscriptState,
  firstProofSeen: firstProofSeen,
  isPermissionBlocked: isPermissionBlocked,
  entryCount: entryCount,
);

SurfacePriorityCandidates _recordCandidates({
  required bool firstRunPositioning,
  bool threeMomentCompletion = true,
  bool firstMomentCapture = false,
  bool secondMomentReturn = false,
}) => SurfacePriorityCandidates.recordReady(
  threeMomentCompletion: threeMomentCompletion,
  firstMomentCapture: firstMomentCapture,
  secondMomentReturn: secondMomentReturn,
  lowFrictionReturn: false,
  whatToNoticeNext: false,
  betaTodaySummary: false,
  openCapturePromptChips: false,
  captureFreedomLine: false,
  firstRunPositioning: firstRunPositioning,
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

Future<void> _pumpCard(
  WidgetTester tester, {
  required FirstRunPositioningResult result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: FirstRunPositioningCard.test(result: result)),
    ),
  );
  await tester.pump();
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    FirstRunPositioningAnalytics.resetForTest();
    FirstRunPositioningAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    ArchiveBetaMissionGate.resetForTest();
    analyticsEvents.clear();
  });

  tearDown(() {
    FirstRunPositioningAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
  });

  group('FirstRunPositioningEngine', () {
    test('visible at zero entries if priority allows', () {
      final result = _result();
      expect(_shouldShow(result: result), isTrue);

      final audit = SurfacePriorityEngine.auditRecordReady(
        entryCount: 0,
        source: 'test',
        candidates: _recordCandidates(
          firstRunPositioning: true,
        ),
      );
      expect(
        audit.isVisible(
          SurfacePriorityCardKey.firstRunPositioning,
          candidate: true,
        ),
        isTrue,
      );
    });

    test('visible at one entry if priority allows', () {
      final result = _result(entryCount: 1);
      expect(_shouldShow(result: result, entryCount: 1), isTrue);

      final audit = SurfacePriorityEngine.auditRecordReady(
        entryCount: 1,
        source: 'test',
        candidates: _recordCandidates(
          firstRunPositioning: true,
          threeMomentCompletion: false,
          secondMomentReturn: true,
        ),
      );
      expect(audit.guidanceSlot, SurfacePriorityCardKey.secondMomentReturn);
      expect(
        audit.isVisible(
          SurfacePriorityCardKey.firstRunPositioning,
          candidate: true,
        ),
        isTrue,
      );
    });

    test('hidden after first proof', () {
      final result = _result(entryCount: 1);
      expect(
        _shouldShow(result: result, entryCount: 1, firstProofSeen: true),
        isFalse,
      );
    });

    test('hidden recording/degraded', () {
      final result = _result();
      expect(
        _shouldShow(result: result, isRecording: true),
        isFalse,
      );
      expect(
        _shouldShow(
          result: result,
          isDegradedTranscriptState: true,
        ),
        isFalse,
      );
    });

    test('does not stack beyond surface priority limits', () {
      final crowded = SurfacePriorityEngine.auditRecordReady(
        entryCount: 0,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: true,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          firstRunPositioning: true,
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

      expect(crowded.guidanceSlot, SurfacePriorityCardKey.lowFrictionReturn);
      expect(
        crowded.isVisible(
          SurfacePriorityCardKey.firstRunPositioning,
          candidate: true,
        ),
        isFalse,
      );
    });

    test('metadata-only analytics', () {
      FirstRunPositioningAnalytics.seen(result: _result());
      final event = analyticsEvents.single;
      expect(event.event, FirstRunPositioningAnalytics.seenEvent);
      expect(event.props.keys.toSet(), {'entry_count', 'source'});
      expect(event.props['source'], 'test');
    });

    test('engine source avoids fake data and journal mutations', () {
      const enginePath =
          'lib/features/first_run_positioning/first_run_positioning_engine.dart';
      final source = File(enginePath).readAsStringSync().toLowerCase();
      expect(source.contains('journalstore.save'), isFalse);
      expect(source.contains('journalentry('), isFalse);
      expect(source.contains('fake'), isFalse);
    });
  });

  group('FirstRunPositioningCard', () {
    testWidgets('includes positioning copy without paywall CTA', (
      tester,
    ) async {
      await _pumpCard(tester, result: _result());

      expect(
        find.byKey(const Key('first_run_positioning_card')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Free shows the first useful proof'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Pro keeps the longer proof trail'),
        findsOneWidget,
      );
      expect(find.textContaining('upgrade to pro'), findsNothing);
      expect(find.textContaining('/subscription'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('no paywall CTA', (tester) async {
      await _pumpCard(tester, result: _result());
      final blob = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('paywall')));
      expect(blob, isNot(contains('subscribe')));
    });

    test('copy passes medical guard', () {
      for (final line in FirstRunPositioningCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('TestingArchiveMeScreen', () {
    testWidgets('testing screen includes preview card', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const TestingArchiveMeScreen(),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(FirstRunPositioningCard), findsOneWidget);
    });
  });

  group('Record screen integration', () {
    test('record screen wires first run positioning card', () {
      final source = readRecordScreenLibrarySource();
      expect(source, contains('FirstRunPositioningCard'));
      expect(
        source,
        contains('firstRunPositioning: showFirstRunPositioningCard'),
      );
      expect(source, contains('SurfacePriorityCardKey.firstRunPositioning'));
    });
  });
}