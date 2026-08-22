import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/production_candidate/production_candidate_checklist.dart';
import 'package:archiveme_mobile/features/production_candidate/production_candidate_copy.dart';
import 'package:flutter_test/flutter_test.dart';

ProductionCandidateChecklist _checklist({
  bool betaResultsPassed = true,
  bool proofProtectionBaselineActive = true,
  bool usefulProofStable = true,
  bool tooVagueNotRelevantLow = true,
  bool firstSessionTargetMet = true,
  bool evidenceTrailClearTargetMet = true,
  bool proUnderstandingTargetMet = true,
  bool pricingSignalAcceptable = true,
  bool restorePurchasesVerified = true,
  bool revenueCatProductsVerified = true,
  bool appStoreSupportUrlReady = true,
  bool privacyPolicyReady = true,
  bool appStoreScreenshotsReady = true,
  bool appStoreMetadataReady = true,
  bool productionSecretsRotated = true,
  bool physicalDeviceSmokeTestPassed = true,
  bool testFlightBuildUploaded = true,
}) => ProductionCandidateChecklist(
  betaResultsPassed: betaResultsPassed,
  proofProtectionBaselineActive: proofProtectionBaselineActive,
  usefulProofStable: usefulProofStable,
  tooVagueNotRelevantLow: tooVagueNotRelevantLow,
  firstSessionTargetMet: firstSessionTargetMet,
  evidenceTrailClearTargetMet: evidenceTrailClearTargetMet,
  proUnderstandingTargetMet: proUnderstandingTargetMet,
  pricingSignalAcceptable: pricingSignalAcceptable,
  restorePurchasesVerified: restorePurchasesVerified,
  revenueCatProductsVerified: revenueCatProductsVerified,
  appStoreSupportUrlReady: appStoreSupportUrlReady,
  privacyPolicyReady: privacyPolicyReady,
  appStoreScreenshotsReady: appStoreScreenshotsReady,
  appStoreMetadataReady: appStoreMetadataReady,
  productionSecretsRotated: productionSecretsRotated,
  physicalDeviceSmokeTestPassed: physicalDeviceSmokeTestPassed,
  testFlightBuildUploaded: testFlightBuildUploaded,
);

void main() {
  group('ProductionCandidateChecklist.resolveStatus', () {
    test('beta not passed returns notReady', () {
      expect(
        _checklist(betaResultsPassed: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test('proof baseline missing returns notReady', () {
      expect(
        _checklist(proofProtectionBaselineActive: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test('useful proof unstable returns notReady', () {
      expect(
        _checklist(usefulProofStable: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test('vague or not relevant high returns notReady', () {
      expect(
        _checklist(tooVagueNotRelevantLow: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test('first session not met returns notReady', () {
      expect(
        _checklist(firstSessionTargetMet: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test('evidence trail clarity not met returns notReady', () {
      expect(
        _checklist(evidenceTrailClearTargetMet: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test('Pro understanding not met returns notReady', () {
      expect(
        _checklist(proUnderstandingTargetMet: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test('pricing signal weak returns notReady', () {
      expect(
        _checklist(pricingSignalAcceptable: false).resolveStatus(),
        ProductionCandidateStatus.notReady,
      );
    });

    test(
      'beta passed but restore purchases missing returns betaReadyButStoreNotReady',
      () {
        expect(
          _checklist(restorePurchasesVerified: false).resolveStatus(),
          ProductionCandidateStatus.betaReadyButStoreNotReady,
        );
      },
    );

    test(
      'beta passed but RevenueCat missing returns betaReadyButStoreNotReady',
      () {
        expect(
          _checklist(revenueCatProductsVerified: false).resolveStatus(),
          ProductionCandidateStatus.betaReadyButStoreNotReady,
        );
      },
    );

    test(
      'beta passed but screenshots metadata privacy support missing returns betaReadyButStoreNotReady',
      () {
        for (final checklist in [
          _checklist(appStoreScreenshotsReady: false),
          _checklist(appStoreMetadataReady: false),
          _checklist(privacyPolicyReady: false),
          _checklist(appStoreSupportUrlReady: false),
          _checklist(physicalDeviceSmokeTestPassed: false),
          _checklist(testFlightBuildUploaded: false),
        ]) {
          expect(
            checklist.resolveStatus(),
            ProductionCandidateStatus.betaReadyButStoreNotReady,
          );
        }
      },
    );

    test(
      'beta and store ready but productionSecretsRotated false returns storeReadyButSecretsNotReady',
      () {
        expect(
          _checklist(productionSecretsRotated: false).resolveStatus(),
          ProductionCandidateStatus.storeReadyButSecretsNotReady,
        );
      },
    );

    test('everything true returns readyForSubmission', () {
      expect(
        _checklist().resolveStatus(),
        ProductionCandidateStatus.readyForSubmission,
      );
    });
  });

  group('ProductionCandidateCopy.report', () {
    test('includes missing items', () {
      final checklist = _checklist(
        restorePurchasesVerified: false,
        appStoreMetadataReady: false,
      );
      final status = checklist.resolveStatus();
      final report = ProductionCandidateCopy.report(checklist, status);

      expect(status, ProductionCandidateStatus.betaReadyButStoreNotReady);
      expect(
        report.missingItems,
        containsAll(['Restore purchases verified', 'App Store metadata ready']),
      );
      expect(
        report.missingItems,
        isNot(contains('Beta results reader passed')),
      );
    });

    test('returns correct nextAction for each status', () {
      final cases = <ProductionCandidateStatus, String>{
        ProductionCandidateStatus.notReady:
            'Do one targeted repair based on the beta results reader. Do not add broad features.',
        ProductionCandidateStatus.betaReadyButStoreNotReady:
            'Complete App Store, RevenueCat, restore purchases, device, and metadata checks.',
        ProductionCandidateStatus.storeReadyButSecretsNotReady:
            'Rotate exposed production secrets before launch.',
        ProductionCandidateStatus.readyForSubmission:
            'Freeze scope and submit the production candidate.',
      };

      for (final entry in cases.entries) {
        final checklist = switch (entry.key) {
          ProductionCandidateStatus.notReady => _checklist(
            betaResultsPassed: false,
          ),
          ProductionCandidateStatus.betaReadyButStoreNotReady => _checklist(
            restorePurchasesVerified: false,
          ),
          ProductionCandidateStatus.storeReadyButSecretsNotReady => _checklist(
            productionSecretsRotated: false,
          ),
          ProductionCandidateStatus.readyForSubmission => _checklist(),
        };
        final report = ProductionCandidateCopy.report(checklist, entry.key);
        expect(report.title, ProductionCandidateCopy.titleFor(entry.key));
        expect(report.nextAction, entry.value);
        expect(report.guardrail, ProductionCandidateCopy.guardrail);
      }
    });

    test('passes metadata-safe guard', () {
      for (final text in ProductionCandidateCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected UI or product behavior files touched', () {
      for (final path in [
        'lib/features/production_candidate/production_candidate_checklist.dart',
        'lib/features/production_candidate/production_candidate_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('record_screen'), isFalse);
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('BetaRepairLab'), isFalse);
      }
    });
  });
}