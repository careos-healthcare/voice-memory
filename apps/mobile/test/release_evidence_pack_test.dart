import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/release_evidence/release_evidence_pack.dart';
import 'package:archiveme_mobile/features/release_evidence/release_evidence_pack_copy.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/features/v1_surface_scope/v1_surface_scope_audit.dart';
import 'package:flutter_test/flutter_test.dart';

ReleaseEvidencePackInput _input({
  bool cleanGitStatus = true,
  bool versionBuildCaptured = true,
  bool physicalIphoneSmokeTest = true,
  bool physicalIpadSmokeTest = true,
  bool productionApiSmokeTest = true,
  bool voiceSavePath = true,
  bool typedSavePath = true,
  bool firstProofPath = true,
  bool proPaywallRoute = true,
  bool revenueCatProductLoad = true,
  bool sandboxPurchase = true,
  bool restorePurchases = true,
  bool entitlementPersistence = true,
  bool supportUrl = true,
  bool privacyUrl = true,
  bool termsUrl = true,
  bool screenshots = true,
  bool testFlightUploaded = true,
  bool secretsRotated = true,
}) => ReleaseEvidencePackInput(
  cleanGitStatus: cleanGitStatus,
  versionBuildCaptured: versionBuildCaptured,
  physicalIphoneSmokeTest: physicalIphoneSmokeTest,
  physicalIpadSmokeTest: physicalIpadSmokeTest,
  productionApiSmokeTest: productionApiSmokeTest,
  voiceSavePath: voiceSavePath,
  typedSavePath: typedSavePath,
  firstProofPath: firstProofPath,
  proPaywallRoute: proPaywallRoute,
  revenueCatProductLoad: revenueCatProductLoad,
  sandboxPurchase: sandboxPurchase,
  restorePurchases: restorePurchases,
  entitlementPersistence: entitlementPersistence,
  supportUrl: supportUrl,
  privacyUrl: privacyUrl,
  termsUrl: termsUrl,
  screenshots: screenshots,
  testFlightUploaded: testFlightUploaded,
  secretsRotated: secretsRotated,
);

void main() {
  group('ReleaseEvidencePack.resolve', () {
    test(
      'all evidence present with secrets rotated returns readyForSubmission',
      () {
        final result = ReleaseEvidencePack.resolve(_input());
        expect(result.status, ReleaseEvidencePackStatus.readyForSubmission);
        expect(result.missingItems, isEmpty);
        expect(result.message, ReleaseEvidencePackCopy.submissionLine);
      },
    );

    test('all evidence present without secrets returns readyForTestFlight', () {
      final result = ReleaseEvidencePack.resolve(_input(secretsRotated: false));
      expect(result.status, ReleaseEvidencePackStatus.readyForTestFlight);
      expect(result.missingItems, isEmpty);
      expect(result.message, ReleaseEvidencePackCopy.testFlightLine);
    });

    test('missing evidence returns notReady', () {
      final result = ReleaseEvidencePack.resolve(
        _input(cleanGitStatus: false, sandboxPurchase: false),
      );
      expect(result.status, ReleaseEvidencePackStatus.notReady);
      expect(result.message, ReleaseEvidencePackCopy.notReadyLine);
      expect(result.missingItems, isNotEmpty);
    });

    test('each required evidence item blocks readiness when missing', () {
      for (final item in ReleaseEvidencePack.requiredEvidenceItems) {
        final input = _withMissing(item);
        final result = ReleaseEvidencePack.resolve(input);
        expect(
          result.status,
          ReleaseEvidencePackStatus.notReady,
          reason: item.name,
        );
        expect(result.missingItems, contains(item), reason: item.name);
      }
    });

    test('missing items are returned in deterministic order', () {
      final missing = ReleaseEvidencePack.missingItems(
        _input(
          cleanGitStatus: false,
          voiceSavePath: false,
          testFlightUploaded: false,
        ),
      );
      expect(missing, [
        ReleaseEvidenceItem.cleanGitStatus,
        ReleaseEvidenceItem.voiceSavePath,
        ReleaseEvidenceItem.testFlightUploaded,
      ]);
    });

    test('secrets rotation alone does not block required evidence count', () {
      final missing = ReleaseEvidencePack.missingItems(
        _input(secretsRotated: false),
      );
      expect(missing, isEmpty);
    });
  });

  group('ReleaseEvidencePackCopy', () {
    test('headline says Release evidence pack', () {
      expect(ReleaseEvidencePackCopy.headline, 'Release evidence pack');
    });

    test('body says proof only not product work', () {
      expect(
        ReleaseEvidencePackCopy.body.toLowerCase(),
        contains('proof only'),
      );
      expect(
        ReleaseEvidencePackCopy.body.toLowerCase(),
        contains('not product work'),
      );
      expect(
        ReleaseEvidencePackCopy.guardrail.toLowerCase(),
        contains('proof only'),
      );
    });

    test('labels cover all required evidence items', () {
      for (final item in ReleaseEvidencePack.requiredEvidenceItems) {
        expect(
          ReleaseEvidencePack.labelFor(item),
          isNotEmpty,
          reason: item.name,
        );
      }
    });

    test('copy passes advice guard', () {
      for (final text in ReleaseEvidencePackCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing or purchase logic', () {
      for (final path in [
        'lib/features/release_evidence/release_evidence_pack.dart',
        'lib/features/release_evidence/release_evidence_pack_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
      }
    });

    test('docs file exists and describes evidence pack', () {
      final doc = File('docs/RELEASE_EVIDENCE_PACK.md').readAsStringSync();
      expect(doc.toLowerCase(), contains('release evidence pack'));
      expect(doc.toLowerCase(), contains('testflight'));
      expect(doc.toLowerCase(), contains('restore purchases'));
    });

    test('core V1 surfaces remain allowed', () {
      expect(
        V1SurfaceScopeAudit.audit(
          const V1SurfaceScopeAuditInput(
            surface: V1VisibleSurface.record,
            requestsProductDeletion: false,
            requestsLayoutChange: false,
            isReleaseBlocker: false,
          ),
        ).decision,
        V1ScopeDecision.coreAllowed,
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

ReleaseEvidencePackInput _withMissing(ReleaseEvidenceItem item) {
  return ReleaseEvidencePackInput(
    cleanGitStatus: item != ReleaseEvidenceItem.cleanGitStatus,
    versionBuildCaptured: item != ReleaseEvidenceItem.versionBuildCaptured,
    physicalIphoneSmokeTest:
        item != ReleaseEvidenceItem.physicalIphoneSmokeTest,
    physicalIpadSmokeTest: item != ReleaseEvidenceItem.physicalIpadSmokeTest,
    productionApiSmokeTest: item != ReleaseEvidenceItem.productionApiSmokeTest,
    voiceSavePath: item != ReleaseEvidenceItem.voiceSavePath,
    typedSavePath: item != ReleaseEvidenceItem.typedSavePath,
    firstProofPath: item != ReleaseEvidenceItem.firstProofPath,
    proPaywallRoute: item != ReleaseEvidenceItem.proPaywallRoute,
    revenueCatProductLoad: item != ReleaseEvidenceItem.revenueCatProductLoad,
    sandboxPurchase: item != ReleaseEvidenceItem.sandboxPurchase,
    restorePurchases: item != ReleaseEvidenceItem.restorePurchases,
    entitlementPersistence: item != ReleaseEvidenceItem.entitlementPersistence,
    supportUrl: item != ReleaseEvidenceItem.supportUrl,
    privacyUrl: item != ReleaseEvidenceItem.privacyUrl,
    termsUrl: item != ReleaseEvidenceItem.termsUrl,
    screenshots: item != ReleaseEvidenceItem.screenshots,
    testFlightUploaded: item != ReleaseEvidenceItem.testFlightUploaded,
    secretsRotated: true,
  );
}