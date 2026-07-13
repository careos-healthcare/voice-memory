import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_blocker_priority/release_blocker_priority.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/v1_surface_scope/v1_surface_scope_audit.dart';
import 'package:voicememory_mobile/features/v1_surface_scope/v1_surface_scope_audit_copy.dart';

V1SurfaceScopeAuditInput _input({
  V1VisibleSurface surface = V1VisibleSurface.record,
  bool requestsProductDeletion = false,
  bool requestsLayoutChange = false,
  bool isReleaseBlocker = false,
}) =>
    V1SurfaceScopeAuditInput(
      surface: surface,
      requestsProductDeletion: requestsProductDeletion,
      requestsLayoutChange: requestsLayoutChange,
      isReleaseBlocker: isReleaseBlocker,
    );

void main() {
  group('V1SurfaceScopeAudit.scopeFor', () {
    test('core surfaces classify as coreV1', () {
      for (final surface in V1SurfaceScopeAudit.coreSurfaces) {
        expect(
          V1SurfaceScopeAudit.scopeFor(surface),
          V1SurfaceScope.coreV1,
          reason: surface.name,
        );
      }
    });

    test('secondary surfaces classify as secondaryHidden', () {
      for (final surface in V1SurfaceScopeAudit.secondarySurfaces) {
        expect(
          V1SurfaceScopeAudit.scopeFor(surface),
          V1SurfaceScope.secondaryHidden,
          reason: surface.name,
        );
      }
    });

    test('release blocker surfaces classify as releaseBlockerOnly', () {
      for (final surface in V1SurfaceScopeAudit.releaseBlockerSurfaces) {
        expect(
          V1SurfaceScopeAudit.scopeFor(surface),
          V1SurfaceScope.releaseBlockerOnly,
          reason: surface.name,
        );
      }
    });
  });

  group('V1SurfaceScopeAudit.audit', () {
    test('core surfaces remain allowed and required for release', () {
      for (final surface in V1SurfaceScopeAudit.coreSurfaces) {
        final result = V1SurfaceScopeAudit.audit(_input(surface: surface));
        expect(result.decision, V1ScopeDecision.coreAllowed, reason: surface.name);
        expect(result.requiredForRelease, isTrue, reason: surface.name);
        expect(result.visibleInV1, isTrue, reason: surface.name);
      }
    });

    test('secondary surfaces are not required for release', () {
      for (final surface in V1SurfaceScopeAudit.secondarySurfaces) {
        final result = V1SurfaceScopeAudit.audit(_input(surface: surface));
        expect(
          result.decision,
          V1ScopeDecision.secondaryNotRequiredForRelease,
          reason: surface.name,
        );
        expect(result.requiredForRelease, isFalse, reason: surface.name);
        expect(result.visibleInV1, isFalse, reason: surface.name);
      }
    });

    test('release blocker surfaces are allowed for blocker work only', () {
      for (final surface in V1SurfaceScopeAudit.releaseBlockerSurfaces) {
        final result = V1SurfaceScopeAudit.audit(_input(surface: surface));
        expect(
          result.decision,
          V1ScopeDecision.releaseBlockerAllowed,
          reason: surface.name,
        );
        expect(result.requiredForRelease, isTrue, reason: surface.name);
        expect(result.visibleInV1, isFalse, reason: surface.name);
      }
    });

    test('product deletion is blocked', () {
      final result = V1SurfaceScopeAudit.audit(
        _input(requestsProductDeletion: true),
      );
      expect(result.decision, V1ScopeDecision.blockProductDeletion);
      expect(result.requiredForRelease, isFalse);
    });

    test('layout change blocked unless release blocker', () {
      final blocked = V1SurfaceScopeAudit.audit(
        _input(
          surface: V1VisibleSurface.record,
          requestsLayoutChange: true,
        ),
      );
      final allowed = V1SurfaceScopeAudit.audit(
        _input(
          surface: V1VisibleSurface.purchase,
          requestsLayoutChange: true,
          isReleaseBlocker: true,
        ),
      );
      expect(
        blocked.decision,
        V1ScopeDecision.blockLayoutChangeUnlessBlocker,
      );
      expect(allowed.decision, V1ScopeDecision.releaseBlockerAllowed);
    });
  });

  group('V1SurfaceScopeAuditCopy', () {
    test('headline says V1 surface scope audit', () {
      expect(V1SurfaceScopeAuditCopy.headline, 'V1 surface scope audit');
    });

    test('body says no product deletion', () {
      expect(
        V1SurfaceScopeAuditCopy.body.toLowerCase(),
        contains('no product deletion'),
      );
    });

    test('coreLine lists core V1 surfaces', () {
      final lower = V1SurfaceScopeAuditCopy.coreLine.toLowerCase();
      expect(lower, contains('record'));
      expect(lower, contains('first useful proof'));
      expect(lower, contains('longer proof trail'));
      expect(lower, contains('restore purchases'));
    });

    test('secondaryLine lists secondary hidden surfaces', () {
      final lower = V1SurfaceScopeAuditCopy.secondaryLine.toLowerCase();
      expect(lower, contains('reports'));
      expect(lower, contains('dashboards'));
      expect(lower, contains('action items'));
      expect(lower, contains('archive packs'));
      expect(lower, contains('search'));
      expect(lower, contains('widgets'));
    });

    test('blockerLine lists release blocker surfaces', () {
      final lower = V1SurfaceScopeAuditCopy.blockerLine.toLowerCase();
      expect(lower, contains('purchase'));
      expect(lower, contains('restore'));
      expect(lower, contains('entitlement'));
      expect(lower, contains('testflight'));
      expect(lower, contains('secrets'));
    });

    test('guardrail blocks product deletion and layout changes', () {
      expect(
        V1SurfaceScopeAuditCopy.guardrail.toLowerCase(),
        contains('no product deletion'),
      );
      expect(
        V1SurfaceScopeAuditCopy.guardrail.toLowerCase(),
        contains('no layout changes unless a release blocker'),
      );
    });

    test('copy passes advice guard', () {
      for (final text in V1SurfaceScopeAuditCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/v1_surface_scope/v1_surface_scope_audit.dart',
        'lib/features/v1_surface_scope/v1_surface_scope_audit_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
      }
    });

    test('release candidate freeze still blocks new product feature', () {
      expect(
        ReleaseCandidateFreeze.build(
          const ReleaseCandidateFreezeInput(
            changeType: ReleaseCandidateChangeType.newDashboard,
            blocksRelease: false,
            blocksPurchase: false,
            blocksRestore: false,
            blocksEntitlement: false,
            causesCrash: false,
            risksAppStoreRejection: false,
            affectsSecuritySecrets: false,
            fixesFirstJourneyComprehension: false,
            fixesCriticalProofTrust: false,
            addsNewUserFacingSurface: false,
            changesPricingOrPaywall: false,
            changesProofThresholds: false,
            changesRecordLayout: false,
          ),
        ).allowed,
        isFalse,
      );
    });

    test('release blocker priority still reaches ready state', () {
      expect(
        ReleaseBlockerPriority.build(
          const ReleaseBlockerPriorityInput(
            freezeActive: true,
            hasSecuritySecretsBlocker: false,
            hasCrash: false,
            blocksStoreReadiness: false,
            risksAppStoreRejection: false,
            blocksPurchase: false,
            blocksRestore: false,
            blocksEntitlement: false,
            firstJourneyComprehensionWeak: false,
            criticalProofTrustWeak: false,
            paidIntentSignalWeak: false,
          ),
        ).decision,
        ReleaseBlockerPriorityDecision.readyForPaidIntentBeta,
      );
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(
        ProofDetailRepairCopy.whyThisOneLine,
        contains('clearest specific repeat'),
      );
    });

    test('record screen remains capture-first', () {
      final audit = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
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
          betaProofLift: true,
        ),
      );
      expect(audit.proofCardKey, 'timelineProofMoment');
      expect(audit.guidanceCardKey, isNull);
    });
  });
}
