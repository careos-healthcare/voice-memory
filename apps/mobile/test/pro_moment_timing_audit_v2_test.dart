import 'dart:io';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:archiveme_mobile/features/pro_moment_timing/pro_moment_timing_audit_v2_copy.dart';
import 'package:archiveme_mobile/features/pro_moment_timing/pro_moment_timing_audit_v2_engine.dart';
import 'package:archiveme_mobile/features/pro_moment_timing/pro_moment_timing_audit_v2_model.dart';
import 'package:archiveme_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/beta/pro_moment_timing_audit_v2_card.dart';
import 'package:archiveme_research/screens/testing_archiveme_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _privateTranscript =
    'I had no capacity but I said yes again to the extra meeting today.';

ProMomentTimingAuditV2Check _check(
  ProMomentTimingAuditV2Snapshot snapshot,
  ProMomentTimingAuditV2CheckId id,
) => snapshot.checks.firstWhere((check) => check.id == id);

Future<void> _pumpCard(
  WidgetTester tester, {
  ProMomentTimingAuditV2Snapshot? snapshot,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProMomentTimingAuditV2Card(
            snapshotOverride: snapshot ?? ProMomentTimingAuditV2Engine.build(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(ArchiveBetaMissionGate.resetForTest);
  tearDown(ArchiveBetaMissionGate.resetForTest);

  group('ProMomentTimingAuditV2Engine', () {
    test('verifies Pro blocked before proof', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(
          snapshot,
          ProMomentTimingAuditV2CheckId.neverBeforeFirstProof,
        ).status,
        ProMomentTimingAuditV2Status.ready,
      );
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: const ProBridgeVisibilityInput(
            surface: ProBridgeVisibilitySurface.recordReady,
            source: 'test',
            entryCount: 2,
            isPro: false,
            postProofProBridgeEnabled: true,
            hasFirstProof: false,
          ),
        ),
        isFalse,
      );
    });

    test('verifies Pro appears after useful proof', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(snapshot, ProMomentTimingAuditV2CheckId.afterUsefulProof).status,
        ProMomentTimingAuditV2Status.ready,
      );
    });

    test('verifies Pro appears after strong proof', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(snapshot, ProMomentTimingAuditV2CheckId.afterStrongProof).status,
        ProMomentTimingAuditV2Status.ready,
      );
    });

    test('verifies Pro appears after fresh return', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(snapshot, ProMomentTimingAuditV2CheckId.afterFreshReturn).status,
        ProMomentTimingAuditV2Status.ready,
      );
    });

    test('verifies Pro blocked after too vague', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(snapshot, ProMomentTimingAuditV2CheckId.blockedTooVague).status,
        ProMomentTimingAuditV2Status.ready,
      );
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: const ProBridgeVisibilityInput(
            surface: ProBridgeVisibilitySurface.recordReady,
            source: 'test',
            entryCount: 3,
            isPro: false,
            postProofProBridgeEnabled: true,
            hasFirstProof: true,
            hasTimelineProofVisible: true,
            feedbackState: ProofQualityFeedbackState.tooVague,
          ),
        ),
        isFalse,
      );
    });

    test('verifies Pro blocked after not relevant', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(
          snapshot,
          ProMomentTimingAuditV2CheckId.blockedNotRelevant,
        ).status,
        ProMomentTimingAuditV2Status.ready,
      );
    });

    test('verifies Already knew requires delta', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(
          snapshot,
          ProMomentTimingAuditV2CheckId.alreadyKnewNeedsDelta,
        ).status,
        ProMomentTimingAuditV2Status.ready,
      );
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: const ProBridgeVisibilityInput(
            surface: ProBridgeVisibilitySurface.recordReady,
            source: 'test',
            entryCount: 3,
            isPro: false,
            postProofProBridgeEnabled: true,
            hasFirstProof: true,
            feedbackState: ProofQualityFeedbackState.alreadyKnewThis,
          ),
        ),
        isFalse,
      );
      expect(
        ProBridgeVisibilityEngine.shouldShow(
          input: const ProBridgeVisibilityInput(
            surface: ProBridgeVisibilitySurface.recordReady,
            source: 'test',
            entryCount: 3,
            isPro: false,
            postProofProBridgeEnabled: true,
            hasFirstProof: true,
            hasCorrectionMemoryVisible: true,
            feedbackState: ProofQualityFeedbackState.alreadyKnewThis,
          ),
        ),
        isTrue,
      );
    });

    test('verifies paywall source is valueMoment from proof bridge', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(
          snapshot,
          ProMomentTimingAuditV2CheckId.paywallSourceProofConnected,
        ).status,
        ProMomentTimingAuditV2Status.ready,
      );
      expect(
        ProMomentTimingAuditV2Engine.expectedProBridgePaywallSource,
        PaywallSource.valueMoment,
      );
      expect(
        PaywallValueSharpeningCopy.isProofConnectedSource(
          ProMomentTimingAuditV2Engine.expectedProBridgePaywallSource,
        ),
        isTrue,
      );
    });

    test('verifies only one Pro card', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(
        _check(
          snapshot,
          ProMomentTimingAuditV2CheckId.oneProCardPerSurface,
        ).status,
        ProMomentTimingAuditV2Status.ready,
      );

      final audit = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: 3,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          whatChanged: false,
          firstProofPayoff: true,
          returnPayoff: false,
          timelineProofMomentPostSave: true,
          proofSpecificityPostSave: false,
          betaProofFeedback: false,
          proBridgeVisibility: true,
          proEvidenceValue: true,
          proLockMoment: true,
          privateReportProBridge: true,
        ),
      );
      final proVisible = audit.visibleCardKeys
          .where(
            (key) =>
                key == SurfacePriorityCardKey.proBridgeVisibility ||
                key == SurfacePriorityCardKey.proEvidenceValue ||
                key == SurfacePriorityCardKey.proLockMoment ||
                key == SurfacePriorityCardKey.privateReportProBridge,
          )
          .length;
      expect(proVisible, 1);
    });

    test('all checks pass with correct diagnosis', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      expect(snapshot.readyCount, snapshot.checks.length);
      expect(snapshot.blockedCount, 0);
      expect(
        snapshot.diagnoses.any(
          (diagnosis) =>
              diagnosis.id == ProMomentTimingAuditV2DiagnosisId.correct,
        ),
        isTrue,
      );
      expect(
        snapshot.diagnoses.first.title,
        ProMomentTimingAuditV2Copy.diagnosisCorrect,
      );
    });

    test('verifies no private text/secrets in displayed copy', () {
      final snapshot = ProMomentTimingAuditV2Engine.build();
      final joined = snapshot.allDisplayedText.join('\n').toLowerCase();
      expect(joined, isNot(contains(_privateTranscript.toLowerCase())));
      expect(joined, isNot(contains('sk_live')));
      expect(joined, isNot(contains('appl_')));
      expect(ProofSurfaceAdviceGuard.passes(snapshot.title), isTrue);
    });

    test('protected billing constants unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
      final engineSource = File(
        'lib/features/pro_moment_timing/pro_moment_timing_audit_v2_engine.dart',
      ).readAsStringSync();
      expect(engineSource, isNot(contains('purchasePackage')));
      expect(engineSource, isNot(contains('restorePurchases')));
    });
  });

  group('ProMomentTimingAuditV2Card', () {
    testWidgets('testing screen includes audit card', (tester) async {
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

      expect(find.byType(ProMomentTimingAuditV2Card), findsOneWidget);
    });

    testWidgets('renders checks and correct diagnosis', (tester) async {
      await _pumpCard(tester);

      expect(
        find.byKey(const Key('pro_moment_timing_audit_v2_card')),
        findsOneWidget,
      );
      expect(
        find.text(ProMomentTimingAuditV2Copy.checkNeverBeforeFirstProof),
        findsOneWidget,
      );
      expect(
        find.text(ProMomentTimingAuditV2Copy.diagnosisCorrect),
        findsOneWidget,
      );
    });

    testWidgets('hidden when beta mission gate disabled', (tester) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ProMomentTimingAuditV2Card()),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('pro_moment_timing_audit_v2_hidden')),
        findsOneWidget,
      );
    });
  });
}