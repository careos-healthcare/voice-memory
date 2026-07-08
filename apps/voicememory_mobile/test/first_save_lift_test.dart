import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/first_save_lift/first_save_lift_analytics.dart';
import 'package:voicememory_mobile/features/first_save_lift/first_save_lift_copy.dart';
import 'package:voicememory_mobile/features/first_save_lift/first_save_lift_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/widgets/record/first_save_lift_card.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required VoidCallback onTypeOneSentence,
  required VoidCallback onRecordInstead,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FirstSaveLiftCard.test(
          result: FirstSaveLiftEngine.build(
            entryCount: 0,
            source: 'test',
          ),
          onTypeOneSentence: onTypeOneSentence,
          onRecordInstead: onRecordInstead,
          onExampleSelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

SurfacePriorityCandidates _recordCandidates({
  bool firstSaveLift = false,
  bool betaActivationPath = false,
}) =>
    SurfacePriorityCandidates.recordReady(
      firstSaveLift: firstSaveLift,
      betaActivationPath: betaActivationPath,
      threeMomentCompletion: false,
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
    );

void main() {
  setUp(() {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    FirstSaveLiftAnalytics.resetForTest();
  });

  group('FirstSaveLiftCopy', () {
    test('uses zero-entry lift copy', () {
      expect(FirstSaveLiftCopy.title, 'Save one small moment');
      expect(
        FirstSaveLiftCopy.body,
        'One sentence is enough. ArchiveMe needs a first real moment before it can show what returns.',
      );
      expect(FirstSaveLiftCopy.primaryCta, 'Type one sentence');
      expect(FirstSaveLiftCopy.secondaryCta, 'Record instead');
      expect(FirstSaveLiftCopy.exampleKeptCheckingAgain, 'I kept checking again');
    });
  });

  group('FirstSaveLiftEngine', () {
    test('shows at zero entries when beta enabled', () {
      final result = FirstSaveLiftEngine.build(entryCount: 0, source: 'test');
      expect(
        FirstSaveLiftEngine.shouldShow(
          result: result,
          betaMissionEnabled: true,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isTrue,
      );
    });

    test('hidden when beta off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      final result = FirstSaveLiftEngine.build(entryCount: 0, source: 'test');
      expect(
        FirstSaveLiftEngine.shouldShow(
          result: result,
          betaMissionEnabled: false,
          isReady: true,
          isRecording: false,
          isPostSave: false,
          isDegradedTranscriptState: false,
          isPermissionBlocked: false,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test('hidden after first save', () {
      final result = FirstSaveLiftEngine.build(entryCount: 1, source: 'test');
      expect(result.shouldShow, isFalse);
    });
  });

  group('FirstSaveLiftCard', () {
    testWidgets('primary and secondary CTAs invoke handlers', (tester) async {
      var typed = false;
      var recorded = false;
      await _pumpCard(
        tester,
        onTypeOneSentence: () => typed = true,
        onRecordInstead: () => recorded = true,
      );

      await tester.tap(find.byKey(const Key('first_save_lift_primary_cta')));
      await tester.pump();
      expect(typed, isTrue);

      await tester.tap(find.byKey(const Key('first_save_lift_secondary_cta')));
      await tester.pump();
      expect(recorded, isTrue);
    });
  });

  group('FirstSaveLiftAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      FirstSaveLiftAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      final result = FirstSaveLiftEngine.build(entryCount: 0, source: 'test');
      FirstSaveLiftAnalytics.seen(result: result);
      FirstSaveLiftAnalytics.ctaTapped(
        result: result,
        actionType: FirstSaveLiftActionType.typeOneSentence,
      );

      expect(events, [
        FirstSaveLiftAnalytics.seenEvent,
        FirstSaveLiftAnalytics.ctaTappedEvent,
      ]);
      for (final props in properties) {
        expect(props.keys, contains('source'));
        expect(props.keys, contains('entry_count'));
        expect(props.containsKey('transcript'), isFalse);
      }
      expect(properties.last['action_type'], 'type_one_sentence');
    });
  });

  group('SurfacePriorityEngine first save lift', () {
    test('wins guidance slot over beta activation path at zero entries', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 0,
        source: 'test',
        candidates: _recordCandidates(
          firstSaveLift: true,
          betaActivationPath: true,
        ),
      );

      expect(result.guidanceSlot, SurfacePriorityCardKey.firstSaveLift);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaActivationPath,
          candidate: true,
        ),
        isFalse,
      );
      expect(result.hiddenReasons, contains(SurfacePriorityCopy.hiddenReasonGuidanceCap));
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('restore purchases unchanged', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
    });

    test('record screen integrates first save lift card', () {
      final source = File('lib/screens/record_screen.dart').readAsStringSync();
      expect(source, contains('FirstSaveLiftCard'));
      expect(source, contains('SurfacePriorityCardKey.firstSaveLift'));
    });

    test('testing screen includes compact preview', () {
      final source =
          File('lib/screens/testing_archiveme_screen.dart').readAsStringSync();
      expect(source, contains('FirstSaveLiftCard.test'));
    });
  });
}
