import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:voicememory_mobile/billing/restore_purchases_copy.dart';
import 'package:voicememory_mobile/billing/revenuecat_service.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_activation_path/beta_activation_path_analytics.dart';
import 'package:voicememory_mobile/features/beta_activation_path/beta_activation_path_copy.dart';
import 'package:voicememory_mobile/features/beta_activation_path/beta_activation_path_engine.dart';
import 'package:voicememory_mobile/features/beta_activation_path/beta_activation_path_model.dart';
import 'package:voicememory_mobile/features/beta_activation_path/beta_activation_path_store.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/beta/beta_activation_path_card.dart';

import 'support/recording_feature_source.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/beta_activation_path/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

BetaActivationPathContext _context({
  int entryCount = 0,
  bool betaMissionEnabled = true,
  bool dismissedForToday = false,
  bool hasUsefulProof = false,
  bool hasTimelineProof = false,
  bool hasPaywallSeen = false,
  bool hasPurchaseCtaTapped = false,
  bool strongerProCardVisible = false,
  bool isReady = true,
  bool isRecording = false,
  bool isPostSave = false,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool isPermissionBlocked = false,
}) => BetaActivationPathContext(
  source: 'test',
  entryCount: entryCount,
  betaMissionEnabled: betaMissionEnabled,
  dismissedForToday: dismissedForToday,
  hasUsefulProof: hasUsefulProof,
  hasTimelineProof: hasTimelineProof,
  hasPaywallSeen: hasPaywallSeen,
  hasPurchaseCtaTapped: hasPurchaseCtaTapped,
  strongerProCardVisible: strongerProCardVisible,
  isReady: isReady,
  isRecording: isRecording,
  isPostSave: isPostSave,
  isDegradedTranscriptState: isDegradedTranscriptState,
  isPostSaveDegradedState: isPostSaveDegradedState,
  whatChangedQuestionActive: whatChangedQuestionActive,
  patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
  isPermissionBlocked: isPermissionBlocked,
);

BetaActivationPathResult _buildResult({BetaActivationPathContext? context}) =>
    BetaActivationPathEngine.build(context: context ?? _context());

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaActivationPathResult result,
  VoidCallback? onPrimaryCta,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BetaActivationPathCard.test(
          result: result,
          onPrimaryCta: onPrimaryCta,
        ),
      ),
    ),
  );
  await tester.pump();
}

SurfacePriorityCandidates _recordCandidates({
  bool betaActivationPath = false,
  bool betaActivationPathRevenue = false,
  bool threeMomentCompletion = false,
  bool proBridgeVisibility = false,
  bool proEvidenceValue = false,
}) => SurfacePriorityCandidates.recordReady(
  betaActivationPath: betaActivationPath,
  betaActivationPathRevenue: betaActivationPathRevenue,
  threeMomentCompletion: threeMomentCompletion,
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
  proBridgeVisibility: proBridgeVisibility,
  proEvidenceValue: proEvidenceValue,
  privateReportProBridge: false,
  suppressLegacyEducation: false,
);

void main() {
  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaActivationPathAnalytics.resetForTest();
    await BetaActivationPathStore.resetForTest(_MemoryPrefs());
  });

  tearDown(BetaActivationPathAnalytics.resetForTest);

  group('BetaActivationPathEngine stages', () {
    test('0 entries shows first-save stage', () {
      final result = _buildResult(context: _context(entryCount: 0));
      expect(result.shouldShow, isTrue);
      expect(result.stage, BetaActivationPathStage.firstSave);
      expect(result.title, BetaActivationPathCopy.firstSaveTitle);
      expect(result.primaryCta, BetaActivationPathCopy.firstSavePrimaryCta);
      expect(result.slot, BetaActivationPathSlot.guidance);
    });

    test('1 entry shows second-save stage', () {
      final result = _buildResult(context: _context(entryCount: 1));
      expect(result.stage, BetaActivationPathStage.secondSave);
      expect(result.title, BetaActivationPathCopy.secondSaveTitle);
    });

    test('2 entries shows third-save stage', () {
      final result = _buildResult(context: _context(entryCount: 2));
      expect(result.stage, BetaActivationPathStage.thirdSave);
      expect(result.title, BetaActivationPathCopy.thirdSaveTitle);
    });

    test('3+ entries without useful proof shows proof-check stage', () {
      final result = _buildResult(
        context: _context(entryCount: 3, hasUsefulProof: false),
      );
      expect(result.stage, BetaActivationPathStage.proofCheck);
      expect(result.title, BetaActivationPathCopy.proofCheckTitle);
      expect(result.slot, BetaActivationPathSlot.revenue);
    });

    test('useful proof without paywall shows value-moment stage', () {
      final result = _buildResult(
        context: _context(
          entryCount: 4,
          hasUsefulProof: true,
          hasPaywallSeen: false,
        ),
      );
      expect(result.stage, BetaActivationPathStage.valueMoment);
      expect(result.title, BetaActivationPathCopy.valueMomentTitle);
    });

    test('paywall seen without CTA shows Pro review stage', () {
      final result = _buildResult(
        context: _context(
          entryCount: 4,
          hasUsefulProof: true,
          hasPaywallSeen: true,
          hasPurchaseCtaTapped: false,
        ),
      );
      expect(result.stage, BetaActivationPathStage.proReview);
      expect(result.title, BetaActivationPathCopy.proReviewTitle);
    });

    test('hidden when beta flag off', () {
      final result = _buildResult(context: _context(betaMissionEnabled: false));
      expect(result.shouldShow, isFalse);
    });

    test('hidden while recording', () {
      expect(
        BetaActivationPathEngine.shouldShowCard(
          _context(isRecording: true),
          stage: BetaActivationPathStage.firstSave,
          slot: BetaActivationPathSlot.guidance,
        ),
        isFalse,
      );
    });

    test('hidden while degraded', () {
      expect(
        BetaActivationPathEngine.shouldShowCard(
          _context(isDegradedTranscriptState: true),
          stage: BetaActivationPathStage.firstSave,
          slot: BetaActivationPathSlot.guidance,
        ),
        isFalse,
      );
    });

    test('hidden during WhatChanged', () {
      expect(
        BetaActivationPathEngine.shouldShowCard(
          _context(whatChangedQuestionActive: true),
          stage: BetaActivationPathStage.firstSave,
          slot: BetaActivationPathSlot.guidance,
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox', () {
      expect(
        BetaActivationPathEngine.shouldShowCard(
          _context(patternReviewInboxHasActiveItems: true),
          stage: BetaActivationPathStage.firstSave,
          slot: BetaActivationPathSlot.guidance,
        ),
        isFalse,
      );
    });

    test('hidden when stronger Pro card visible on value moment', () {
      final result = _buildResult(
        context: _context(
          entryCount: 4,
          hasUsefulProof: true,
          strongerProCardVisible: true,
        ),
      );
      expect(result.shouldShow, isFalse);
    });
  });

  group('BetaActivationPathCard', () {
    testWidgets('primary CTA invokes handler', (tester) async {
      var tapped = false;
      await _pumpCard(
        tester,
        result: _buildResult(context: _context(entryCount: 0)),
        onPrimaryCta: () => tapped = true,
      );

      await tester.tap(
        find.byKey(const Key('beta_activation_path_primary_cta')),
      );
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('secondary dismisses for the day', (tester) async {
      final prefs = _MemoryPrefs();
      await BetaActivationPathStore.resetForTest(prefs);
      await _pumpCard(
        tester,
        result: _buildResult(context: _context(entryCount: 0)),
        onPrimaryCta: () {},
      );

      await tester.tap(
        find.byKey(const Key('beta_activation_path_secondary_cta')),
      );
      await tester.pump();

      expect(BetaActivationPathStore.isDismissedToday, isTrue);
      expect(
        find.byKey(const Key('beta_activation_path_card_hidden')),
        findsOneWidget,
      );
    });

    test('no private text or user-specific evidence', () {
      final displayed = BetaActivationPathCopy.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in BetaActivationPathCopy.bannedPrivateTerms) {
        expect(displayed, isNot(contains(banned)));
      }
      for (final banned in BetaActivationPathCopy.bannedEvidenceTerms) {
        expect(displayed, isNot(contains(banned)));
      }
    });

    test('does not create fake entries in copy', () {
      for (final line in BetaActivationPathCopy.allVisibleStrings()) {
        expect(line.toLowerCase(), isNot(contains('fake entry')));
        expect(line.toLowerCase(), isNot(contains('sample transcript')));
      }
    });
  });

  group('BetaActivationPathAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      BetaActivationPathAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      final result = _buildResult(context: _context(entryCount: 1));
      BetaActivationPathAnalytics.seen(result: result);
      BetaActivationPathAnalytics.ctaTapped(
        result: result,
        actionType: BetaActivationPathActionType.saveAnotherMoment,
      );
      BetaActivationPathAnalytics.dismissed(result: result);

      expect(events, [
        BetaActivationPathAnalytics.seenEvent,
        BetaActivationPathAnalytics.ctaTappedEvent,
        BetaActivationPathAnalytics.dismissedEvent,
      ]);
      for (final props in properties) {
        expect(
          props.keys,
          containsAll([
            'source',
            'stage',
            'entry_count',
            'has_useful_proof',
            'has_timeline_proof',
            'has_paywall_seen',
          ]),
        );
        expect(props.containsKey('product_id'), isFalse);
        expect(props.containsKey('transcript'), isFalse);
      }
    });
  });

  group('SurfacePriorityEngine beta activation path', () {
    test('allows only one guidance slot', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 0,
        source: 'test',
        candidates: _recordCandidates(
          betaActivationPath: true,
          threeMomentCompletion: true,
        ),
      );

      expect(result.guidanceSlot, SurfacePriorityCardKey.betaActivationPath);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.threeMomentCompletion,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.hiddenReasons,
        contains(SurfacePriorityCopy.hiddenReasonGuidanceCap),
      );
    });

    test('revenue slot yields to stronger Pro cards', () {
      final result = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'test',
        candidates: _recordCandidates(
          betaActivationPathRevenue: true,
          proBridgeVisibility: true,
        ),
      );

      expect(result.proSlot, SurfacePriorityCardKey.proBridgeVisibility);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.betaActivationPathRevenue,
          candidate: true,
        ),
        isFalse,
      );
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(RevenueCatService.proEntitlementId, 'archive_loop_pro');
    });

    test('restore purchases unchanged', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
    });

    test('record screen routes Pro path through valueMoment paywall', () {
      final source = readRecordingFeatureSource();
      expect(source, contains('BetaActivationPathCard'));
      expect(source, contains('_handleBetaActivationPathPrimaryCta'));
      expect(source, contains('PaywallSource.valueMoment'));
    });

    test('testing screen includes compact preview', () {
      final source = File(
        'lib/screens/testing_archiveme_screen.dart',
      ).readAsStringSync();
      expect(source, contains('BetaActivationPathCard.test'));
      expect(source, contains('showDiagnosis: true'));
    });
  });
}
