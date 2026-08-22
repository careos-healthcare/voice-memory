import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/first_proof_field_readiness/first_proof_field_readiness.dart';
import 'package:archiveme_mobile/features/first_proof_field_readiness/first_proof_field_readiness_copy.dart';
import 'package:archiveme_mobile/features/first_proof_truth/first_proof_truth_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _docsPath = 'docs/architecture/first_proof_field_readiness.md';

FirstProofFieldReadinessInput _input({
  int usableMomentCount = 3,
  ProofConfidenceLevel? confidenceLevel = ProofConfidenceLevel.strong,
  bool hasSafeAnchor = true,
  BetaProofFeedbackType? feedbackType = BetaProofFeedbackType.useful,
  FirstProofTruthAnswer? truthAnswer,
  bool proofCorrected = false,
  bool? understoodWhyAppeared = true,
  bool? understoodWhatToSaveNext = true,
  bool proofThresholdStillThree = true,
  bool betaReadinessStillGuardsThree = true,
}) => FirstProofFieldReadinessInput(
  usableMomentCount: usableMomentCount,
  confidenceLevel: confidenceLevel,
  hasSafeAnchor: hasSafeAnchor,
  feedbackType: feedbackType,
  truthAnswer: truthAnswer,
  proofCorrected: proofCorrected,
  understoodWhyAppeared: understoodWhyAppeared,
  understoodWhatToSaveNext: understoodWhatToSaveNext,
  proofThresholdStillThree: proofThresholdStillThree,
  betaReadinessStillGuardsThree: betaReadinessStillGuardsThree,
);

FirstProofFieldReadinessSignal _signal(
  FirstProofFieldReadinessResult result,
  FirstProofFieldReadinessSignalId id,
) => result.signals.firstWhere((signal) => signal.id == id);

void main() {
  group('FirstProofFieldReadiness.build', () {
    test('engine tracks ten canonical signals', () {
      final result = FirstProofFieldReadiness.build(_input());
      expect(result.signals.length, FirstProofFieldReadiness.signalCount);
      expect(result.signals.map((signal) => signal.id).toList(), [
        FirstProofFieldReadinessSignalId.userSavedThreeUsableMoments,
        FirstProofFieldReadinessSignalId.strongProofAppeared,
        FirstProofFieldReadinessSignalId.watchOnlyAppearedInstead,
        FirstProofFieldReadinessSignalId.noSafeAnchor,
        FirstProofFieldReadinessSignalId.proofAccepted,
        FirstProofFieldReadinessSignalId.proofCorrected,
        FirstProofFieldReadinessSignalId.proofTooVague,
        FirstProofFieldReadinessSignalId.proofNotRelevant,
        FirstProofFieldReadinessSignalId.userUnderstoodWhyAppeared,
        FirstProofFieldReadinessSignalId.userUnderstoodWhatToSaveNext,
      ]);
    });

    test('fewer than 3 usable moments -> insufficientCapture', () {
      final result = FirstProofFieldReadiness.build(
        _input(usableMomentCount: 2, confidenceLevel: null),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.insufficientCapture,
      );
      expect(
        _signal(
          result,
          FirstProofFieldReadinessSignalId.userSavedThreeUsableMoments,
        ).status,
        FirstProofFieldReadinessSignalStatus.concern,
      );
    });

    test('no safe anchor -> repairAnchorSafety', () {
      final result = FirstProofFieldReadiness.build(
        _input(hasSafeAnchor: false),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.repairAnchorSafety,
      );
      expect(
        _signal(result, FirstProofFieldReadinessSignalId.noSafeAnchor).status,
        FirstProofFieldReadinessSignalStatus.concern,
      );
    });

    test('too vague feedback -> repairProofClarity', () {
      final result = FirstProofFieldReadiness.build(
        _input(feedbackType: BetaProofFeedbackType.tooVague),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.repairProofClarity,
      );
      expect(
        _signal(result, FirstProofFieldReadinessSignalId.proofTooVague).status,
        FirstProofFieldReadinessSignalStatus.concern,
      );
    });

    test('not relevant feedback -> repairProofRelevance', () {
      final result = FirstProofFieldReadiness.build(
        _input(feedbackType: BetaProofFeedbackType.notRelevant),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.repairProofRelevance,
      );
      expect(
        _signal(
          result,
          FirstProofFieldReadinessSignalId.proofNotRelevant,
        ).status,
        FirstProofFieldReadinessSignalStatus.concern,
      );
    });

    test('watch_only instead of strong proof -> repairProofStrength', () {
      final result = FirstProofFieldReadiness.build(
        _input(confidenceLevel: ProofConfidenceLevel.watchOnly),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.repairProofStrength,
      );
      expect(
        _signal(
          result,
          FirstProofFieldReadinessSignalId.watchOnlyAppearedInstead,
        ).status,
        FirstProofFieldReadinessSignalStatus.concern,
      );
      expect(
        _signal(
          result,
          FirstProofFieldReadinessSignalId.strongProofAppeared,
        ).status,
        FirstProofFieldReadinessSignalStatus.concern,
      );
    });

    test('did not understand what to save next -> repairSaveNextGuidance', () {
      final result = FirstProofFieldReadiness.build(
        _input(understoodWhatToSaveNext: false),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.repairSaveNextGuidance,
      );
    });

    test('did not understand why appeared -> repairWhyAppeared', () {
      final result = FirstProofFieldReadiness.build(
        _input(understoodWhyAppeared: false),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.repairWhyAppeared,
      );
    });

    test('accepted useful proof with comprehension -> fieldReady', () {
      final result = FirstProofFieldReadiness.build(_input());
      expect(result.decision, FirstProofFieldReadinessDecision.fieldReady);
      expect(result.fieldReady, isTrue);
      expect(result.thresholdsUnchanged, isTrue);
      expect(
        _signal(result, FirstProofFieldReadinessSignalId.proofAccepted).status,
        FirstProofFieldReadinessSignalStatus.pass,
      );
    });

    test('truth yes counts as proof accepted', () {
      final result = FirstProofFieldReadiness.build(
        _input(feedbackType: null, truthAnswer: FirstProofTruthAnswer.yes),
      );
      expect(
        _signal(result, FirstProofFieldReadinessSignalId.proofAccepted).status,
        FirstProofFieldReadinessSignalStatus.pass,
      );
    });

    test('proof corrected is tracked without blocking fieldReady', () {
      final result = FirstProofFieldReadiness.build(
        _input(
          proofCorrected: true,
          confidenceLevel: ProofConfidenceLevel.corrected,
        ),
      );
      expect(
        _signal(result, FirstProofFieldReadinessSignalId.proofCorrected).status,
        FirstProofFieldReadinessSignalStatus.pass,
      );
      expect(result.decision, FirstProofFieldReadinessDecision.fieldReady);
    });

    test('mixed incomplete comprehension -> needsManualReview', () {
      final result = FirstProofFieldReadiness.build(
        _input(
          feedbackType: null,
          understoodWhyAppeared: null,
          understoodWhatToSaveNext: null,
        ),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.needsManualReview,
      );
    });

    test('threshold drift forces manual review', () {
      final result = FirstProofFieldReadiness.build(
        _input(proofThresholdStillThree: false),
      );
      expect(
        result.decision,
        FirstProofFieldReadinessDecision.needsManualReview,
      );
    });

    test('report exposes canonical copy', () {
      final report = FirstProofFieldReadiness.report(
        FirstProofFieldReadiness.build(_input()),
      );
      expect(report.headline, FirstProofFieldReadinessCopy.headline);
      expect(report.guardrail, FirstProofFieldReadinessCopy.guardrail);
      expect(report.orderLine, FirstProofFieldReadinessCopy.orderLine);
    });
  });

  group('FirstProofFieldReadiness.fromRepoSignals', () {
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
        FirstProofFieldReadiness.detectProofThresholdStillThree(
          archiveEvidenceQualityGateSource,
        ),
        isTrue,
      );
      expect(
        FirstProofFieldReadiness.detectBetaReadinessStillGuardsThree(
          betaReadinessEngineSource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals preserves threshold guards', () {
      final input = FirstProofFieldReadiness.fromRepoSignals(
        archiveEvidenceQualityGateSource: archiveEvidenceQualityGateSource,
        betaReadinessEngineSource: betaReadinessEngineSource,
        confidenceLevel: ProofConfidenceLevel.strong,
        feedbackType: BetaProofFeedbackType.useful,
        understoodWhyAppeared: true,
        understoodWhatToSaveNext: true,
      );
      final result = FirstProofFieldReadiness.build(input);
      expect(result.decision, FirstProofFieldReadinessDecision.fieldReady);
    });
  });

  group('protected regression', () {
    test('docs describe measurement-only scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('do not loosen anchors'));
      expect(doc, contains('do not change thresholds'));
      expect(doc, contains('repair routing only'));
    });

    test('copy guardrail forbids threshold changes', () {
      expect(
        FirstProofFieldReadinessCopy.guardrail.toLowerCase(),
        contains('do not loosen anchors'),
      );
      expect(
        FirstProofFieldReadinessCopy.guardrail.toLowerCase(),
        contains('change thresholds'),
      );
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in FirstProofFieldReadinessCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('required usable moments stays at gate constant', () {
      expect(FirstProofFieldReadiness.requiredUsableMoments, 3);
    });
  });
}