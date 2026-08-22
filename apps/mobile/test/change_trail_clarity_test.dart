import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:archiveme_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity_copy.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:archiveme_mobile/features/payment_blocker_matrix/payment_blocker_decision_matrix.dart';
import 'package:archiveme_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';

ChangeTrailClaritySummary _summary({
  int totalTesters = 30,
  int understoodFirstProofCount = 8,
  int understoodProKeepsTrailCount = 8,
  int understoodReturnsCount = 8,
  int understoodChangesCount = 8,
  int understoodFadesCount = 8,
  int understoodCorrectionsCount = 8,
  int thoughtMoreAiCount = 1,
  int wantedMoreProofCount = 1,
  int wantedRankingCount = 1,
  int wouldPayYesCount = 2,
  int wouldPayMaybeCount = 1,
  int wouldPayNoCount = 2,
}) => ChangeTrailClaritySummary(
  totalTesters: totalTesters,
  understoodFirstProofCount: understoodFirstProofCount,
  understoodProKeepsTrailCount: understoodProKeepsTrailCount,
  understoodReturnsCount: understoodReturnsCount,
  understoodChangesCount: understoodChangesCount,
  understoodFadesCount: understoodFadesCount,
  understoodCorrectionsCount: understoodCorrectionsCount,
  thoughtMoreAiCount: thoughtMoreAiCount,
  wantedMoreProofCount: wantedMoreProofCount,
  wantedRankingCount: wantedRankingCount,
  wouldPayYesCount: wouldPayYesCount,
  wouldPayMaybeCount: wouldPayMaybeCount,
  wouldPayNoCount: wouldPayNoCount,
);

ChangeTrailClaritySummary _fullTrailSummary({int totalTesters = 30}) =>
    _summary(
      totalTesters: totalTesters,
      understoodFirstProofCount: totalTesters == 20 ? 5 : 7,
      understoodProKeepsTrailCount: totalTesters == 20 ? 4 : 6,
      understoodReturnsCount: totalTesters == 20 ? 4 : 6,
      understoodChangesCount: totalTesters == 20 ? 4 : 6,
      understoodFadesCount: totalTesters == 20 ? 4 : 6,
      understoodCorrectionsCount: totalTesters == 20 ? 4 : 6,
      thoughtMoreAiCount: 0,
    );

BetaRepairLabVisibilityInput _repairInput() => const BetaRepairLabVisibilityInput(
  mode: BetaRepairLabMode.evidenceTrailTimelineClarity,
  entryCount: 4,
  source: 'test',
  isPro: false,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
  hasTimelineProofVisible: true,
  hasConfirmedRepeat: true,
  confidenceLevel: ProofConfidenceLevel.watchOnly,
  hasUsefulProofFeedback: false,
  feedbackType: null,
  isNegativeFeedback: false,
  betaMissionEnabled: true,
);

void main() {
  group('ChangeTrailClarity.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        ChangeTrailClarity.resolve(_summary(totalTesters: 19)),
        ChangeTrailClarityDecision.insufficientData,
      );
    });

    test('weak first proof returns repairFirstProof', () {
      expect(
        ChangeTrailClarity.resolve(
          _summary(understoodFirstProofCount: 4),
        ),
        ChangeTrailClarityDecision.repairFirstProof,
      );
    });

    test('weak Pro trail returns repairProTrail', () {
      expect(
        ChangeTrailClarity.resolve(
          _fullTrailSummary().copyWith(understoodProKeepsTrailCount: 3),
        ),
        ChangeTrailClarityDecision.repairProTrail,
      );
    });

    test('more-AI confusion high returns removeMoreAiConfusion', () {
      expect(
        ChangeTrailClarity.resolve(
          _fullTrailSummary().copyWith(thoughtMoreAiCount: 5),
        ),
        ChangeTrailClarityDecision.removeMoreAiConfusion,
      );
    });

    test('weak returns understanding returns explainReturns', () {
      expect(
        ChangeTrailClarity.resolve(
          _fullTrailSummary().copyWith(understoodReturnsCount: 3),
        ),
        ChangeTrailClarityDecision.explainReturns,
      );
    });

    test('weak changes understanding returns explainChanges', () {
      expect(
        ChangeTrailClarity.resolve(
          _fullTrailSummary().copyWith(understoodChangesCount: 3),
        ),
        ChangeTrailClarityDecision.explainChanges,
      );
    });

    test('weak fades understanding returns explainFades', () {
      expect(
        ChangeTrailClarity.resolve(
          _fullTrailSummary().copyWith(understoodFadesCount: 3),
        ),
        ChangeTrailClarityDecision.explainFades,
      );
    });

    test('weak corrections understanding returns explainCorrections', () {
      expect(
        ChangeTrailClarity.resolve(
          _fullTrailSummary().copyWith(understoodCorrectionsCount: 3),
        ),
        ChangeTrailClarityDecision.explainCorrections,
      );
    });

    test(
      'all comprehension passes but payment weak returns pricingValidation',
      () {
        expect(
          ChangeTrailClarity.resolve(
            _fullTrailSummary().copyWith(
              wouldPayYesCount: 0,
              wouldPayMaybeCount: 1,
            ),
          ),
          ChangeTrailClarityDecision.pricingValidation,
        );
      },
    );

    test('all comprehension and payment pass returns releaseCandidate', () {
      expect(
        ChangeTrailClarity.resolve(_fullTrailSummary()),
        ChangeTrailClarityDecision.releaseCandidate,
      );
    });
  });

  group('ChangeTrailClarityCopy', () {
    test('title says What the trail shows', () {
      expect(ChangeTrailClarityCopy.title, 'What the trail shows');
    });

    test('body says after the first proof', () {
      expect(ChangeTrailClarityCopy.body, contains('After the first proof'));
    });

    test('body says keeps watching the same repeat', () {
      expect(
        ChangeTrailClarityCopy.body,
        contains('keeps watching the same repeat'),
      );
    });

    test(
      'body includes comes back / changes shape / softer / stronger / fades / corrected',
      () {
        final body = ChangeTrailClarityCopy.body.toLowerCase();
        expect(body, contains('comes back'));
        expect(body, contains('changes shape'));
        expect(body, contains('softer'));
        expect(body, contains('stronger'));
        expect(body, contains('fades'));
        expect(body, contains('corrected'));
      },
    );

    test('returnsLine explains same repeat appears again', () {
      expect(
        ChangeTrailClarityCopy.returnsLine,
        contains('same repeat appears again'),
      );
    });

    test('changesLine explains different way', () {
      expect(
        ChangeTrailClarityCopy.changesLine,
        contains('slightly different way'),
      );
    });

    test('softensLine explains less intense or easier to notice', () {
      expect(
        ChangeTrailClarityCopy.softensLine,
        contains('less intense or easier to notice'),
      );
    });

    test('strengthensLine explains more clearly or more often', () {
      expect(
        ChangeTrailClarityCopy.strengthensLine,
        contains('more clearly or more often'),
      );
    });

    test('fadesLine explains stops showing up as much', () {
      expect(
        ChangeTrailClarityCopy.fadesLine,
        contains('stops showing up as much'),
      );
    });

    test('correctedLine explains too vague or not relevant', () {
      expect(
        ChangeTrailClarityCopy.correctedLine,
        contains('too vague or not relevant'),
      );
    });

    test('proLine says Free shows first useful proof', () {
      expect(
        ChangeTrailClarityCopy.proLine,
        contains('Free shows the first useful proof'),
      );
    });

    test('proLine says Pro keeps change trail over time', () {
      expect(
        ChangeTrailClarityCopy.proLine,
        contains('Pro keeps this change trail over time'),
      );
    });

    test('valueLine says not for more AI', () {
      expect(ChangeTrailClarityCopy.valueLine, contains('not for more AI'));
    });

    test('guardrail blocks more proof or ranking', () {
      expect(
        ChangeTrailClarityCopy.guardrail,
        contains('Do not add more proof or ranking'),
      );
    });

    test('copy does not position ArchiveMe as voice chat', () {
      for (final text in ChangeTrailClarityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('voice chat'), isFalse, reason: text);
        expect(lower.contains('voice assistant'), isFalse, reason: text);
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in [
        ChangeTrailClarityCopy.title,
        ChangeTrailClarityCopy.body,
        ChangeTrailClarityCopy.returnsLine,
        ChangeTrailClarityCopy.changesLine,
        ChangeTrailClarityCopy.softensLine,
        ChangeTrailClarityCopy.strengthensLine,
        ChangeTrailClarityCopy.fadesLine,
        ChangeTrailClarityCopy.correctedLine,
        ChangeTrailClarityCopy.proLine,
        ChangeTrailClarityCopy.valueLine,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in [
        ChangeTrailClarityCopy.title,
        ChangeTrailClarityCopy.body,
        ChangeTrailClarityCopy.returnsLine,
        ChangeTrailClarityCopy.changesLine,
        ChangeTrailClarityCopy.softensLine,
        ChangeTrailClarityCopy.strengthensLine,
        ChangeTrailClarityCopy.fadesLine,
        ChangeTrailClarityCopy.correctedLine,
        ChangeTrailClarityCopy.proLine,
        ChangeTrailClarityCopy.valueLine,
      ]) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        expect(lower.contains('advice'), isFalse, reason: text);
        expect(lower.contains('coaching'), isFalse, reason: text);
        expect(lower.contains('therapy'), isFalse, reason: text);
        expect(lower.contains('diagnosis'), isFalse, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/change_trail_clarity/change_trail_clarity.dart',
        'lib/features/change_trail_clarity/change_trail_clarity_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
        expect(source.contains('paywall'), isFalse);
      }
    });

    test('existing diagnostic modules behaviour unchanged', () {
      expect(
        ReleaseCandidateComprehension.resolve(_fullComprehension()),
        ReleaseCandidateComprehensionDecision.releaseCandidate,
      );
      expect(
        CoreArchiveJourneyGuardrail.allowsVoiceAssistantPositioning(),
        isFalse,
      );
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _repairInput(),
          hasProEngagement: true,
        ),
        isFalse,
      );
      expect(
        PaymentBlockerDecisionMatrix.resolve(
          const PaymentBlockerSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 6,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 1,
            needSeeOverTimeCount: 1,
            needStrongerProofCount: 1,
            needRankingBeforePayingCount: 1,
            priceTooHighCount: 1,
            worthPayingCount: 3,
          ),
        ),
        PaymentBlockerDecision.productionCandidate,
      );
      expect(
        ValuePropRankingDiagnostic.resolve(
          const ValuePropRankingDiagnosticSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 6,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 1,
            needStrongerProofCount: 1,
            needSeeOverTimeCount: 1,
            needRankingBeforePayingCount: 1,
            priceTooHighCount: 1,
            worthPayingCount: 3,
          ),
        ),
        ValuePropRankingDiagnosticDecision.productionCandidate,
      );
      expect(
        PricingOfferValidationV2.resolve(
          const PricingOfferValidationSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodLongerTrailCount: 6,
            understoodNotMoreAiCount: 6,
            payYesCount: 2,
            payMaybeCount: 1,
            payNoCount: 1,
            priceTooHighCount: 1,
            needStrongerProofCount: 1,
            needRankingCount: 7,
            ctaTapCount: 1,
          ),
        ),
        PricingOfferValidationDecision.holdRanking,
      );
      expect(
        EvidenceTrailProUnderstanding.resolve(
          const EvidenceTrailProUnderstandingSummary(
            totalTesters: 30,
            usefulProofCount: 7,
            understoodFirstProofCount: 6,
            understoodLongerTrailCount: 6,
            understoodProKeepsChangesCount: 6,
            thoughtProWasMoreAiCount: 1,
            wantedRankingCount: 1,
            paywallCtaTapCount: 1,
            wouldPayYesMaybeCount: 3,
          ),
        ),
        EvidenceTrailProUnderstandingDecision.productionCandidate,
      );
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(
        ProofDetailRepairCopy.whyThisOneLine,
        contains('clearest specific repeat'),
      );
    });

    test(
      'record screen remains capture-first without stacking extra cards',
      () {
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
      },
    );
  });
}

ReleaseCandidateComprehensionSummary _fullComprehension() =>
    const ReleaseCandidateComprehensionSummary(
      totalTesters: 30,
      understoodNotVoiceChatCount: 7,
      understoodFirstProofCount: 7,
      understoodWhyAppearedCount: 7,
      understoodConfirmCorrectCount: 7,
      understoodProKeepsTrailCount: 6,
      understoodReturnsChangesFadesCorrectionsCount: 6,
      thoughtItWasVoiceChatCount: 0,
      thoughtItWasMoreAiCount: 0,
      wouldPayYesCount: 2,
      wouldPayMaybeCount: 1,
      wouldPayNoCount: 1,
    );

extension on ChangeTrailClaritySummary {
  ChangeTrailClaritySummary copyWith({
    int? totalTesters,
    int? understoodFirstProofCount,
    int? understoodProKeepsTrailCount,
    int? understoodReturnsCount,
    int? understoodChangesCount,
    int? understoodFadesCount,
    int? understoodCorrectionsCount,
    int? thoughtMoreAiCount,
    int? wantedMoreProofCount,
    int? wantedRankingCount,
    int? wouldPayYesCount,
    int? wouldPayMaybeCount,
    int? wouldPayNoCount,
  }) => ChangeTrailClaritySummary(
    totalTesters: totalTesters ?? this.totalTesters,
    understoodFirstProofCount:
        understoodFirstProofCount ?? this.understoodFirstProofCount,
    understoodProKeepsTrailCount:
        understoodProKeepsTrailCount ?? this.understoodProKeepsTrailCount,
    understoodReturnsCount:
        understoodReturnsCount ?? this.understoodReturnsCount,
    understoodChangesCount:
        understoodChangesCount ?? this.understoodChangesCount,
    understoodFadesCount: understoodFadesCount ?? this.understoodFadesCount,
    understoodCorrectionsCount:
        understoodCorrectionsCount ?? this.understoodCorrectionsCount,
    thoughtMoreAiCount: thoughtMoreAiCount ?? this.thoughtMoreAiCount,
    wantedMoreProofCount: wantedMoreProofCount ?? this.wantedMoreProofCount,
    wantedRankingCount: wantedRankingCount ?? this.wantedRankingCount,
    wouldPayYesCount: wouldPayYesCount ?? this.wouldPayYesCount,
    wouldPayMaybeCount: wouldPayMaybeCount ?? this.wouldPayMaybeCount,
    wouldPayNoCount: wouldPayNoCount ?? this.wouldPayNoCount,
  );
}