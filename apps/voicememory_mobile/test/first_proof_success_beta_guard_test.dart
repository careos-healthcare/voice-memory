import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/first_proof_success_beta/first_proof_success_beta_copy.dart';
import 'package:voicememory_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';

const _docsPath = 'docs/FIRST_PROOF_SUCCESS_BETA_GUARD.md';

FirstProofSuccessBetaInput _input({
  int usableMomentCount = 3,
  bool hasSafeAnchor = true,
  bool hasMatchQuality = true,
  ProofConfidenceLevel? proofConfidence = ProofConfidenceLevel.strong,
  bool proofShown = true,
  bool proofAccepted = true,
  bool proofCorrected = false,
  bool tooVagueSelected = false,
  bool notRelevantSelected = false,
  bool userUnderstoodWhy = true,
  bool userSavedAnotherAfterProof = false,
  bool proPromiseSeen = false,
  bool proofThresholdStillThree = true,
  bool betaReadinessStillGuardsThree = true,
}) =>
    FirstProofSuccessBetaInput(
      usableMomentCount: usableMomentCount,
      hasSafeAnchor: hasSafeAnchor,
      hasMatchQuality: hasMatchQuality,
      proofConfidence: proofConfidence,
      proofShown: proofShown,
      proofAccepted: proofAccepted,
      proofCorrected: proofCorrected,
      tooVagueSelected: tooVagueSelected,
      notRelevantSelected: notRelevantSelected,
      userUnderstoodWhy: userUnderstoodWhy,
      userSavedAnotherAfterProof: userSavedAnotherAfterProof,
      proPromiseSeen: proPromiseSeen,
      proofThresholdStillThree: proofThresholdStillThree,
      betaReadinessStillGuardsThree: betaReadinessStillGuardsThree,
    );

FirstProofSuccessBetaSignal _signal(
  FirstProofSuccessBetaResult result,
  FirstProofSuccessBetaSignalId id,
) =>
    result.signals.firstWhere((signal) => signal.id == id);

void main() {
  group('FirstProofSuccessBetaGuard.build', () {
    test('engine tracks eleven canonical signals', () {
      final result = FirstProofSuccessBetaGuard.build(_input());
      expect(result.signals.length, FirstProofSuccessBetaGuard.signalCount);
      expect(
        result.signals.map((signal) => signal.id).toList(),
        [
          FirstProofSuccessBetaSignalId.usableMomentsReady,
          FirstProofSuccessBetaSignalId.safeAnchorPresent,
          FirstProofSuccessBetaSignalId.matchQualityPresent,
          FirstProofSuccessBetaSignalId.proofConfidenceStrong,
          FirstProofSuccessBetaSignalId.proofShown,
          FirstProofSuccessBetaSignalId.proofAccepted,
          FirstProofSuccessBetaSignalId.proofCorrected,
          FirstProofSuccessBetaSignalId.tooVagueSelected,
          FirstProofSuccessBetaSignalId.notRelevantSelected,
          FirstProofSuccessBetaSignalId.userUnderstoodWhy,
          FirstProofSuccessBetaSignalId.userSavedAnotherAfterProof,
        ],
      );
    });

    test('no safe anchor does not loosen proof', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(hasSafeAnchor: false),
      );
      expect(result.decision, FirstProofSuccessBetaDecision.noSafeAnchor);
      expect(result.thresholdsUnchanged, isTrue);
      expect(
        _signal(result, FirstProofSuccessBetaSignalId.safeAnchorPresent).status,
        FirstProofSuccessBetaSignalStatus.concern,
      );
      expect(
        FirstProofSuccessBetaGuard.requiredUsableMoments,
        3,
      );
    });

    test('not enough moments routes to more real moments', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(usableMomentCount: 2, proofConfidence: null),
      );
      expect(result.decision, FirstProofSuccessBetaDecision.notEnoughMoments);
      expect(
        FirstProofSuccessBetaCopy.recommendationFor(result.decision),
        contains('more real moments'),
      );
      expect(
        _signal(result, FirstProofSuccessBetaSignalId.usableMomentsReady)
            .status,
        FirstProofSuccessBetaSignalStatus.concern,
      );
    });

    test('accepted proof is working', () {
      final result = FirstProofSuccessBetaGuard.build(_input());
      expect(result.decision, FirstProofSuccessBetaDecision.proofWorking);
      expect(result.proofWorking, isTrue);
      expect(
        _signal(result, FirstProofSuccessBetaSignalId.proofAccepted).status,
        FirstProofSuccessBetaSignalStatus.pass,
      );
    });

    test('too vague routes to proof trust repair', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(
          proofAccepted: false,
          tooVagueSelected: true,
        ),
      );
      expect(result.decision, FirstProofSuccessBetaDecision.proofTooVagueRisk);
      expect(
        FirstProofSuccessBetaCopy.recommendationFor(result.decision),
        contains('proof trust repair'),
      );
      expect(
        _signal(result, FirstProofSuccessBetaSignalId.tooVagueSelected).status,
        FirstProofSuccessBetaSignalStatus.concern,
      );
    });

    test('not relevant routes to proof trust repair', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(
          proofAccepted: false,
          notRelevantSelected: true,
        ),
      );
      expect(result.decision, FirstProofSuccessBetaDecision.proofNotRelevantRisk);
      expect(
        FirstProofSuccessBetaCopy.recommendationFor(result.decision),
        contains('proof trust repair'),
      );
      expect(
        _signal(result, FirstProofSuccessBetaSignalId.notRelevantSelected)
            .status,
        FirstProofSuccessBetaSignalStatus.concern,
      );
    });

    test('proof accepted + Pro seen can mark proofStrongEnoughForPro', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(proPromiseSeen: true),
      );
      expect(
        result.decision,
        FirstProofSuccessBetaDecision.proofStrongEnoughForPro,
      );
      expect(result.proofWorking, isTrue);
    });

    test('proof corrected counts as working when accepted path is not set', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(
          proofAccepted: false,
          proofCorrected: true,
          proofConfidence: ProofConfidenceLevel.corrected,
        ),
      );
      expect(result.decision, FirstProofSuccessBetaDecision.proofWorking);
    });

    test('proof shown without feedback needs feedback', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(
          proofAccepted: false,
          proofCorrected: false,
          tooVagueSelected: false,
          notRelevantSelected: false,
        ),
      );
      expect(
        result.decision,
        FirstProofSuccessBetaDecision.proofShownNeedsFeedback,
      );
    });

    test('weak input quality routes to prompt guidance', () {
      final result = FirstProofSuccessBetaGuard.build(
        _input(
          hasMatchQuality: false,
          proofConfidence: ProofConfidenceLevel.watchOnly,
        ),
      );
      expect(result.decision, FirstProofSuccessBetaDecision.weakInputQuality);
      expect(
        FirstProofSuccessBetaCopy.recommendationFor(result.decision),
        contains('prompt'),
      );
    });

    test('report exposes canonical copy', () {
      final report = FirstProofSuccessBetaGuard.report(
        FirstProofSuccessBetaGuard.build(_input()),
      );
      expect(report.headline, FirstProofSuccessBetaCopy.headline);
      expect(report.guardrail, FirstProofSuccessBetaCopy.guardrail);
      expect(report.orderLine, FirstProofSuccessBetaCopy.orderLine);
    });
  });

  group('FirstProofSuccessBetaGuard.fromRepoSignals', () {
    late String archiveEvidenceQualityGateSource;
    late String betaReadinessEngineSource;

    setUpAll(() {
      archiveEvidenceQualityGateSource = File(
        'lib/features/archive_evidence/archive_evidence_quality_gate.dart',
      ).readAsStringSync();
      betaReadinessEngineSource = File(
        'lib/features/beta_readiness/beta_readiness_engine.dart',
      ).readAsStringSync();
    });

    test('repo still keeps minProofEntryCount at 3', () {
      expect(
        FirstProofSuccessBetaGuard.detectProofThresholdStillThree(
          archiveEvidenceQualityGateSource,
        ),
        isTrue,
      );
      expect(
        FirstProofSuccessBetaGuard.detectBetaReadinessStillGuardsThree(
          betaReadinessEngineSource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals preserves threshold guards', () {
      final input = FirstProofSuccessBetaGuard.fromRepoSignals(
        archiveEvidenceQualityGateSource: archiveEvidenceQualityGateSource,
        betaReadinessEngineSource: betaReadinessEngineSource,
        proofAccepted: true,
        userUnderstoodWhy: true,
      );
      final result = FirstProofSuccessBetaGuard.build(input);
      expect(result.decision, FirstProofSuccessBetaDecision.proofWorking);
      expect(result.thresholdsUnchanged, isTrue);
    });
  });

  group('protected regression', () {
    test('docs describe measurement-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('do not loosen'));
      expect(doc, contains('minproofentrycount'));
      expect(doc, contains('do not loosen anchor rules'));
      expect(doc, contains('prompt/input guidance only'));
    });

    test('copy guardrail forbids threshold changes', () {
      expect(
        FirstProofSuccessBetaCopy.guardrail.toLowerCase(),
        contains('do not loosen minproofentrycount'),
      );
      expect(
        FirstProofSuccessBetaCopy.guardrail.toLowerCase(),
        contains('anchor rules'),
      );
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in FirstProofSuccessBetaCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('required usable moments stays at gate constant', () {
      expect(FirstProofSuccessBetaGuard.requiredUsableMoments, 3);
    });
  });
}
