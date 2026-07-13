import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/evidence_trail_pro_understanding/evidence_trail_pro_understanding.dart';
import 'package:voicememory_mobile/features/payment_blocker_matrix/payment_blocker_decision_matrix.dart';
import 'package:voicememory_mobile/features/pricing_offer_validation/pricing_offer_validation_v2.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_candidate_comprehension/release_candidate_comprehension.dart';
import 'package:voicememory_mobile/features/release_candidate_comprehension/release_candidate_comprehension_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/value_prop_ranking_diagnostic/value_prop_ranking_diagnostic.dart';

ReleaseCandidateComprehensionSummary _summary({
  int totalTesters = 30,
  int understoodNotVoiceChatCount = 8,
  int understoodFirstProofCount = 8,
  int understoodWhyAppearedCount = 8,
  int understoodConfirmCorrectCount = 8,
  int understoodProKeepsTrailCount = 8,
  int understoodReturnsChangesFadesCorrectionsCount = 8,
  int thoughtItWasVoiceChatCount = 1,
  int thoughtItWasMoreAiCount = 1,
  int wouldPayYesCount = 2,
  int wouldPayMaybeCount = 1,
  int wouldPayNoCount = 2,
}) =>
    ReleaseCandidateComprehensionSummary(
      totalTesters: totalTesters,
      understoodNotVoiceChatCount: understoodNotVoiceChatCount,
      understoodFirstProofCount: understoodFirstProofCount,
      understoodWhyAppearedCount: understoodWhyAppearedCount,
      understoodConfirmCorrectCount: understoodConfirmCorrectCount,
      understoodProKeepsTrailCount: understoodProKeepsTrailCount,
      understoodReturnsChangesFadesCorrectionsCount:
          understoodReturnsChangesFadesCorrectionsCount,
      thoughtItWasVoiceChatCount: thoughtItWasVoiceChatCount,
      thoughtItWasMoreAiCount: thoughtItWasMoreAiCount,
      wouldPayYesCount: wouldPayYesCount,
      wouldPayMaybeCount: wouldPayMaybeCount,
      wouldPayNoCount: wouldPayNoCount,
    );

ReleaseCandidateComprehensionSummary _fullComprehensionSummary({
  int totalTesters = 30,
}) =>
    _summary(
      totalTesters: totalTesters,
      understoodNotVoiceChatCount: totalTesters == 20 ? 5 : 7,
      understoodFirstProofCount: totalTesters == 20 ? 5 : 7,
      understoodWhyAppearedCount: totalTesters == 20 ? 5 : 7,
      understoodConfirmCorrectCount: totalTesters == 20 ? 5 : 7,
      understoodProKeepsTrailCount: totalTesters == 20 ? 4 : 6,
      understoodReturnsChangesFadesCorrectionsCount:
          totalTesters == 20 ? 4 : 6,
      thoughtItWasVoiceChatCount: 0,
    );

BetaRepairLabVisibilityInput _repairInput() =>
    BetaRepairLabVisibilityInput(
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
  group('ReleaseCandidateComprehension.resolve', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        ReleaseCandidateComprehension.resolve(_summary(totalTesters: 19)),
        ReleaseCandidateComprehensionDecision.insufficientData,
      );
    });

    test('voice chat confusion high returns repairPositioning', () {
      expect(
        ReleaseCandidateComprehension.resolve(
          _fullComprehensionSummary().copyWith(thoughtItWasVoiceChatCount: 5),
        ),
        ReleaseCandidateComprehensionDecision.repairPositioning,
      );
    });

    test('not-voice-chat understanding low returns repairPositioning', () {
      expect(
        ReleaseCandidateComprehension.resolve(
          _fullComprehensionSummary().copyWith(
            understoodNotVoiceChatCount: 4,
          ),
        ),
        ReleaseCandidateComprehensionDecision.repairPositioning,
      );
    });

    test('first proof understanding low returns repairFirstProof', () {
      expect(
        ReleaseCandidateComprehension.resolve(
          _fullComprehensionSummary().copyWith(understoodFirstProofCount: 4),
        ),
        ReleaseCandidateComprehensionDecision.repairFirstProof,
      );
    });

    test('why appeared understanding low returns repairWhyAppeared', () {
      expect(
        ReleaseCandidateComprehension.resolve(
          _fullComprehensionSummary().copyWith(understoodWhyAppearedCount: 4),
        ),
        ReleaseCandidateComprehensionDecision.repairWhyAppeared,
      );
    });

    test('confirm/correct understanding low returns repairConfirmCorrect', () {
      expect(
        ReleaseCandidateComprehension.resolve(
          _fullComprehensionSummary().copyWith(
            understoodConfirmCorrectCount: 4,
          ),
        ),
        ReleaseCandidateComprehensionDecision.repairConfirmCorrect,
      );
    });

    test('Pro keeps trail understanding low returns repairProTrail', () {
      expect(
        ReleaseCandidateComprehension.resolve(
          _fullComprehensionSummary().copyWith(
            understoodProKeepsTrailCount: 3,
          ),
        ),
        ReleaseCandidateComprehensionDecision.repairProTrail,
      );
    });

    test(
      'returns/changes/fades/corrections understanding low returns repairChangeTrail',
      () {
        expect(
          ReleaseCandidateComprehension.resolve(
            _fullComprehensionSummary().copyWith(
              understoodReturnsChangesFadesCorrectionsCount: 3,
            ),
          ),
          ReleaseCandidateComprehensionDecision.repairChangeTrail,
        );
      },
    );

    test(
      'all comprehension passes but pay weak returns pricingValidation',
      () {
        expect(
          ReleaseCandidateComprehension.resolve(
            _fullComprehensionSummary().copyWith(
              wouldPayYesCount: 0,
              wouldPayMaybeCount: 1,
            ),
          ),
          ReleaseCandidateComprehensionDecision.pricingValidation,
        );
      },
    );

    test(
      'all comprehension and pay pass returns releaseCandidate',
      () {
        expect(
          ReleaseCandidateComprehension.resolve(_fullComprehensionSummary()),
          ReleaseCandidateComprehensionDecision.releaseCandidate,
        );
      },
    );

    test('conservative fallback returns repairPositioning', () {
      expect(
        ReleaseCandidateComprehension.resolve(
          _summary(
            totalTesters: 30,
            understoodNotVoiceChatCount: 7,
            understoodFirstProofCount: 7,
            understoodWhyAppearedCount: 7,
            understoodConfirmCorrectCount: 7,
            understoodProKeepsTrailCount: 6,
            understoodReturnsChangesFadesCorrectionsCount: 5,
          ),
        ),
        ReleaseCandidateComprehensionDecision.repairChangeTrail,
      );
    });
  });

  group('ReleaseCandidateComprehensionCopy', () {
    test('copy headline says ArchiveMe is the proof trail', () {
      expect(
        ReleaseCandidateComprehensionCopy.headline,
        'ArchiveMe is the proof trail',
      );
    });

    test('copy says public promise and not diary/chat/homework', () {
      expect(
        ReleaseCandidateComprehensionCopy.publicPromise,
        'When something repeats, save one real moment. ArchiveMe compares it later.',
      );
      expect(
        ReleaseCandidateComprehensionCopy.body,
        contains('Not a diary'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.body,
        contains('Not ChatGPT'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.body,
        contains('Not homework'),
      );
    });

    test('copy says one clear repeat', () {
      expect(ReleaseCandidateComprehensionCopy.body, contains('one clear repeat'));
    });

    test('copy says explains why it appeared', () {
      expect(
        ReleaseCandidateComprehensionCopy.body,
        contains('explains why it appeared'),
      );
    });

    test('copy says confirm or correct', () {
      expect(
        ReleaseCandidateComprehensionCopy.body,
        contains('confirm or correct'),
      );
    });

    test('copy says returns/changes/fades/corrected', () {
      final body = ReleaseCandidateComprehensionCopy.body.toLowerCase();
      expect(body, contains('returns'));
      expect(body, contains('changes'));
      expect(body, contains('fades'));
      expect(body, contains('corrected'));
    });

    test('notVoiceChatLine says not diary chat or homework', () {
      expect(
        ReleaseCandidateComprehensionCopy.notVoiceChatLine,
        contains('Not a diary'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.notVoiceChatLine,
        contains('Not ChatGPT'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.notVoiceChatLine,
        contains('Not homework'),
      );
    });

    test('firstProofLine says compare safely', () {
      expect(
        ReleaseCandidateComprehensionCopy.firstProofLine,
        contains('compare safely'),
      );
    });

    test('whyAppearedLine says clearest specific repeat', () {
      expect(
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        contains('clearest specific repeat'),
      );
    });

    test('whyAppearedLine says not necessarily the most important thing', () {
      expect(
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        contains('not necessarily the most important thing'),
      );
    });

    test('confirmCorrectLine includes accurate / too vague / not relevant', () {
      expect(
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        contains('accurate'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        contains('too vague'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        contains('not relevant'),
      );
    });

    test('proTrailLine says longer proof trail', () {
      expect(
        ReleaseCandidateComprehensionCopy.proTrailLine,
        contains('longer proof trail'),
      );
    });

    test('changeProofLine includes returns / changes / fades / corrected', () {
      final line = ReleaseCandidateComprehensionCopy.changeProofLine.toLowerCase();
      expect(line, contains('returns'));
      expect(line, contains('changes'));
      expect(line, contains('fades'));
      expect(line, contains('corrected'));
    });

    test(
      'paymentQuestion asks whether user would pay to keep trail over time',
      () {
        expect(
          ReleaseCandidateComprehensionCopy.paymentQuestion,
          contains('Would you pay to keep that trail over time'),
        );
      },
    );

    test('guardrail blocks release messaging unless users understand evidence trail',
        () {
      expect(
        ReleaseCandidateComprehensionCopy.guardrail,
        contains('Do not ship release-candidate messaging unless users understand'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.guardrail,
        contains('evidence trail'),
      );
      expect(
        ReleaseCandidateComprehensionCopy.guardrail,
        contains('not voice chat'),
      );
    });

    test('copy does not say better than ChatGPT Voice', () {
      for (final text in [
        ReleaseCandidateComprehensionCopy.headline,
        ReleaseCandidateComprehensionCopy.firstProofLine,
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        ReleaseCandidateComprehensionCopy.proTrailLine,
        ReleaseCandidateComprehensionCopy.changeProofLine,
        ReleaseCandidateComprehensionCopy.paymentQuestion,
      ]) {
        expect(
          text.toLowerCase().contains('better than chatgpt'),
          isFalse,
          reason: text,
        );
        expect(
          text.toLowerCase().contains('better chatgpt voice'),
          isFalse,
          reason: text,
        );
      }
    });

    test('copy does not position ArchiveMe as a voice assistant', () {
      for (final text in [
        ReleaseCandidateComprehensionCopy.headline,
        ReleaseCandidateComprehensionCopy.firstProofLine,
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        ReleaseCandidateComprehensionCopy.proTrailLine,
        ReleaseCandidateComprehensionCopy.changeProofLine,
        ReleaseCandidateComprehensionCopy.paymentQuestion,
      ]) {
        expect(
          text.toLowerCase().contains('voice assistant'),
          isFalse,
          reason: text,
        );
      }
    });

    test('copy does not position ArchiveMe as transcription', () {
      for (final text in [
        ReleaseCandidateComprehensionCopy.headline,
        ReleaseCandidateComprehensionCopy.firstProofLine,
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        ReleaseCandidateComprehensionCopy.proTrailLine,
        ReleaseCandidateComprehensionCopy.changeProofLine,
        ReleaseCandidateComprehensionCopy.paymentQuestion,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('transcription'), isFalse, reason: text);
      }
    });

    test('copy does not say more AI analysis', () {
      for (final text in [
        ReleaseCandidateComprehensionCopy.headline,
        ReleaseCandidateComprehensionCopy.firstProofLine,
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        ReleaseCandidateComprehensionCopy.proTrailLine,
        ReleaseCandidateComprehensionCopy.changeProofLine,
        ReleaseCandidateComprehensionCopy.paymentQuestion,
      ]) {
        expect(
          text.toLowerCase().contains('more ai analysis'),
          isFalse,
          reason: text,
        );
      }
    });

    test('copy does not introduce ranking or importance scoring', () {
      for (final text in [
        ReleaseCandidateComprehensionCopy.headline,
        ReleaseCandidateComprehensionCopy.body,
        ReleaseCandidateComprehensionCopy.firstProofLine,
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        ReleaseCandidateComprehensionCopy.proTrailLine,
        ReleaseCandidateComprehensionCopy.changeProofLine,
        ReleaseCandidateComprehensionCopy.paymentQuestion,
      ]) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranking'), isFalse, reason: text);
        expect(lower.contains('importance score'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in [
        ReleaseCandidateComprehensionCopy.headline,
        ReleaseCandidateComprehensionCopy.body,
        ReleaseCandidateComprehensionCopy.firstProofLine,
        ReleaseCandidateComprehensionCopy.whyAppearedLine,
        ReleaseCandidateComprehensionCopy.confirmCorrectLine,
        ReleaseCandidateComprehensionCopy.proTrailLine,
        ReleaseCandidateComprehensionCopy.changeProofLine,
        ReleaseCandidateComprehensionCopy.paymentQuestion,
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
        'lib/features/release_candidate_comprehension/release_candidate_comprehension.dart',
        'lib/features/release_candidate_comprehension/release_candidate_comprehension_copy.dart',
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

    test('record screen remains capture-first without stacking extra cards', () {
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

extension on ReleaseCandidateComprehensionSummary {
  ReleaseCandidateComprehensionSummary copyWith({
    int? totalTesters,
    int? understoodNotVoiceChatCount,
    int? understoodFirstProofCount,
    int? understoodWhyAppearedCount,
    int? understoodConfirmCorrectCount,
    int? understoodProKeepsTrailCount,
    int? understoodReturnsChangesFadesCorrectionsCount,
    int? thoughtItWasVoiceChatCount,
    int? thoughtItWasMoreAiCount,
    int? wouldPayYesCount,
    int? wouldPayMaybeCount,
    int? wouldPayNoCount,
  }) =>
      ReleaseCandidateComprehensionSummary(
        totalTesters: totalTesters ?? this.totalTesters,
        understoodNotVoiceChatCount:
            understoodNotVoiceChatCount ?? this.understoodNotVoiceChatCount,
        understoodFirstProofCount:
            understoodFirstProofCount ?? this.understoodFirstProofCount,
        understoodWhyAppearedCount:
            understoodWhyAppearedCount ?? this.understoodWhyAppearedCount,
        understoodConfirmCorrectCount:
            understoodConfirmCorrectCount ?? this.understoodConfirmCorrectCount,
        understoodProKeepsTrailCount:
            understoodProKeepsTrailCount ?? this.understoodProKeepsTrailCount,
        understoodReturnsChangesFadesCorrectionsCount:
            understoodReturnsChangesFadesCorrectionsCount ??
            this.understoodReturnsChangesFadesCorrectionsCount,
        thoughtItWasVoiceChatCount:
            thoughtItWasVoiceChatCount ?? this.thoughtItWasVoiceChatCount,
        thoughtItWasMoreAiCount:
            thoughtItWasMoreAiCount ?? this.thoughtItWasMoreAiCount,
        wouldPayYesCount: wouldPayYesCount ?? this.wouldPayYesCount,
        wouldPayMaybeCount: wouldPayMaybeCount ?? this.wouldPayMaybeCount,
        wouldPayNoCount: wouldPayNoCount ?? this.wouldPayNoCount,
      );
}
