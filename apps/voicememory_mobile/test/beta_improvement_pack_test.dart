import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_engine.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_pack_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_recommendation_gate.dart';
import 'package:voicememory_mobile/features/beta_improvement/capture_friction_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_packaging_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_utility_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/proof_emotional_clarity_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/record_onboarding_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/return_reason_copy_fix.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_expansion_gate_copy.dart';

BetaTesterOutcome _outcome(Set<BetaDecisionSignal> signals) =>
    BetaTesterOutcome(testerId: 't1', signals: signals);

void main() {
  group('Record/onboarding copy fix', () {
    test('is clear and not broad journal/chatbot/therapy', () {
      final blob =
          RecordOnboardingCopyFix.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, contains('save one real moment'));
      expect(blob, contains('not a diary'));
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('chatbot')));
      expect(blob, isNot(contains('coach')));
      for (final line in RecordOnboardingCopyFix.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('applies only when record onboarding branch is active', () {
      final outcomes = [
        _outcome({BetaDecisionSignal.misunderstoodAsChatbot}),
      ];
      expect(
        BetaImprovementRecommendationGate.activeBranch(
          outcomesOverride: outcomes,
        ),
        BetaImprovementBranch.recordOnboardingCopy,
      );
      expect(
        BetaImprovementPackEngine.recordBody(
          entryCount: 0,
          fallback: 'fallback',
          outcomesOverride: outcomes,
        ),
        RecordOnboardingCopyFix.body,
      );
    });
  });

  group('Capture friction fix', () {
    test('makes typed entry obvious', () {
      expect(
        CaptureFrictionCopyFix.typeFirstPrimaryCta.toLowerCase(),
        contains('type'),
      );
      expect(
        CaptureFrictionCopyFix.typedCapturePrompt,
        'Write one sentence about what just happened.',
      );
      expect(CaptureFrictionCopyFix.compactChipOrder.length, 4);
    });

    test('prefers typed capture first only when branch active', () {
      final outcomes = [
        _outcome({
          BetaDecisionSignal.understoodPromise,
          BetaDecisionSignal.confusedWhatToWrite,
        }),
      ];
      expect(
        BetaImprovementRecommendationGate.activeBranch(
          outcomesOverride: outcomes,
        ),
        BetaImprovementBranch.captureFriction,
      );
      expect(
        BetaImprovementPackEngine.preferTypedCaptureFirst(
          entryCount: 0,
          outcomesOverride: outcomes,
        ),
        isTrue,
      );
    });
  });

  group('Return plan', () {
    test('says no streak and only if it happens again', () {
      final blob =
          ReturnReasonCopyFix.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, contains('no streak'));
      expect(blob, contains('only if it happens again'));
      expect(blob, isNot(contains('homework')));
      expect(blob, isNot(contains('daily challenge')));
      expect(ReturnReasonCopyFix.threeDayPlan.length, 3);
    });
  });

  group('Proof emotional clarity', () {
    test('includes what came back/changed/why without overclaim', () {
      expect(ProofEmotionalClarityCopyFix.whatCameBack, isNotEmpty);
      expect(ProofEmotionalClarityCopyFix.whatChanged, isNotEmpty);
      expect(ProofEmotionalClarityCopyFix.whyMightMatter, isNotEmpty);
      final blob = ProofEmotionalClarityCopyFix.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, contains('not as a diagnosis'));
      expect(blob, contains('cautiously'));
    });
  });

  group('Pro packaging', () {
    test('says longer trail not more AI', () {
      final blob =
          ProPackagingCopyFix.allVisibleStrings().join(' ').toLowerCase();
      expect(blob, contains('longer trail'));
      expect(blob, contains('first useful repeat'));
      expect(blob, isNot(contains('more ai')));
      expect(blob, isNot(contains('chatgpt')));
    });
  });

  group('Pro utility expansion', () {
    test('remains gated preview unless expansion evidence supports it', () {
      final blocked = BetaImprovementRecommendationGate.activeBranch(
        outcomesOverride: [
          _outcome({
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.savedFirstMoment,
            BetaDecisionSignal.askedForReport,
          }),
        ],
      );
      expect(blocked, BetaImprovementBranch.none);

      final allowedOutcomes = [
        _outcome({
          BetaDecisionSignal.understoodPromise,
          BetaDecisionSignal.savedFirstMoment,
          BetaDecisionSignal.returnedDay2,
          BetaDecisionSignal.reachedThreeMoments,
          BetaDecisionSignal.proofFeltMeaningful,
          BetaDecisionSignal.willingToPayForLongerTrail,
          BetaDecisionSignal.askedForExport,
        }),
        _outcome({
          BetaDecisionSignal.understoodPromise,
          BetaDecisionSignal.savedFirstMoment,
          BetaDecisionSignal.returnedDay2,
          BetaDecisionSignal.reachedThreeMoments,
          BetaDecisionSignal.proofFeltMeaningful,
          BetaDecisionSignal.willingToPayForLongerTrail,
          BetaDecisionSignal.askedForExport,
        }),
        _outcome({
          BetaDecisionSignal.understoodPromise,
          BetaDecisionSignal.savedFirstMoment,
          BetaDecisionSignal.returnedDay2,
          BetaDecisionSignal.reachedThreeMoments,
          BetaDecisionSignal.proofFeltMeaningful,
          BetaDecisionSignal.willingToPayForLongerTrail,
          BetaDecisionSignal.askedForHistory,
        }),
      ];
      expect(
        BetaImprovementRecommendationGate.activeBranch(
          outcomesOverride: allowedOutcomes,
        ),
        BetaImprovementBranch.proUtility,
      );
      expect(
        ProUtilityCopyFix.reportPreview.toLowerCase(),
        contains('private monthly'),
      );
      expect(ProUtilityCopyFix.plannedSuffix.toLowerCase(), contains('preview'));
    });
  });

  group('Single active branch', () {
    test('only one beta improvement branch is active at a time', () {
      final outcomes = [
        _outcome({BetaDecisionSignal.misunderstoodAsChatbot}),
        _outcome({
          BetaDecisionSignal.understoodPromise,
          BetaDecisionSignal.savedFirstMoment,
        }),
      ];
      final active = BetaImprovementRecommendationGate.activeBranch(
        outcomesOverride: outcomes,
      );
      expect(active, BetaImprovementBranch.recordOnboardingCopy);
      var activeCount = 0;
      for (final branch in BetaImprovementBranch.values) {
        if (branch == BetaImprovementBranch.none) continue;
        if (BetaImprovementRecommendationGate.isBranchActive(
          branch,
          outcomesOverride: outcomes,
        )) {
          activeCount++;
        }
      }
      expect(activeCount, 1);
    });
  });

  group('Expansion guardrails', () {
    test('expansion branches blocked before beta evidence', () {
      final doc = File(V1ExpansionGateCopy.expansionGatesDocPath).readAsStringSync();
      expect(doc.toLowerCase(), contains('ask your archive'));
      expect(doc.toLowerCase(), contains('loop packs'));
      final result = BetaDecisionEngine.build(
        outcomes: [
          _outcome({
            BetaDecisionSignal.understoodPromise,
            BetaDecisionSignal.askedForReport,
          }),
        ],
      );
      expect(result.primaryRecommendation, BetaNextBuildRecommendation.holdDoNotExpand);
    });

    test('BETA_IMPROVEMENT_PACK doc lists six branches and gating rules', () {
      final doc = File('docs/BETA_IMPROVEMENT_PACK.md').readAsStringSync();
      expect(doc, contains('Record/onboarding copy fix'));
      expect(doc, contains('Capture friction fix'));
      expect(doc, contains('Return reminder'));
      expect(doc, contains('Proof emotional clarity'));
      expect(doc, contains('Pro packaging'));
      expect(doc, contains('Pro utility expansion'));
      expect(doc.toLowerCase(), contains('only one branch'));
      expect(doc, contains('docs/V1_EXPANSION_GATES.md'));
    });
  });
}
