import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/subscription_copy.dart';
import 'package:voicememory_mobile/features/acquisition/audience_wedge_habit_copy.dart';
import 'package:voicememory_mobile/features/acquisition/audience_wedge_model.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_expansion_proof/beta_expansion_proof_copy.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_copy.dart';
import 'package:voicememory_mobile/features/first_five_minutes/first_five_minutes_simplification_copy.dart';
import 'package:voicememory_mobile/features/future_revenue_scope/future_revenue_scope_copy.dart';
import 'package:voicememory_mobile/features/paywall_alignment/paywall_alignment_copy.dart';
import 'package:voicememory_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import 'package:voicememory_mobile/features/pro_conversion_audit/pro_conversion_audit_copy.dart';
import 'package:voicememory_mobile/features/pro_memory/pro_memory_boundary_copy.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise_copy.dart';
import 'package:voicememory_mobile/features/referral_after_proof/referral_after_proof_copy.dart';
import 'package:voicememory_mobile/features/release_candidate/v1_revenue_focus_policy.dart';
import 'package:voicememory_mobile/features/revenue_foundation/revenue_value_copy.dart';
import 'package:voicememory_mobile/features/revenuecat_live_proof/revenuecat_live_proof_copy.dart';
import 'package:voicememory_mobile/features/safe_sharing_future/safe_sharing_future_copy.dart';
import 'package:voicememory_mobile/features/save_a_repeat_habit/save_a_repeat_habit_copy.dart';
import 'package:voicememory_mobile/features/second_moment_return/second_moment_return_copy.dart';
import 'package:voicememory_mobile/features/three_moment_activation/three_moment_activation_copy.dart';
import 'package:voicememory_mobile/product/loop_acquisition_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';

void main() {
  group('V1RevenueFocusPolicy', () {
    test('manifesto line is exact', () {
      expect(
        V1RevenueFocusPolicy.manifestoLine,
        'The revenue increase now comes from sharper packaging, live billing, wedge '
        'acquisition, and a cleaner first proof journey — not more product surface.',
      );
    });

    test('first user journey is concrete', () {
      expect(
        V1RevenueFocusPolicy.firstUserJourney,
        contains('Record one real moment'),
      );
      expect(
        V1RevenueFocusPolicy.firstUserJourney,
        contains('Return when it happens again'),
      );
      expect(
        V1RevenueFocusPolicy.firstUserJourney,
        contains('Pro keeps the longer trail'),
      );
    });

    test('allowed pillars and blocked surfaces are defined', () {
      expect(V1RevenueFocusPolicy.allowedPillars, isNotEmpty);
      expect(V1RevenueFocusPolicy.blockedSurfaces, isNotEmpty);
      expect(
        V1RevenueFocusPolicy.allowedPillars,
        contains('record one real moment'),
      );
      expect(
        V1RevenueFocusPolicy.blockedSurfaces,
        contains('referrals before proof'),
      );
    });

    test('copy passes advice guard', () {
      for (final line in V1RevenueFocusPolicy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });
  });

  group('V1 revenue focus doc', () {
    test('contains exact manifesto line', () {
      final doc = File('docs/V1_REVENUE_FOCUS.md').readAsStringSync();
      expect(doc, contains(V1RevenueFocusPolicy.manifestoLine));
      expect(doc.toLowerCase(), contains('what is allowed now'));
      expect(doc.toLowerCase(), contains('what is deferred'));
      expect(
        doc.toLowerCase(),
        contains('what must be proven before expansion'),
      );
    });
  });

  group('Three-moment activation copy', () {
    test('three lines exist with cautious language', () {
      expect(ThreeMomentActivationCopy.momentOneLine, contains('One moment'));
      expect(
        ThreeMomentActivationCopy.momentTwoLine,
        contains('second similar moment'),
      );
      expect(
        ThreeMomentActivationCopy.momentThreeLine,
        contains('Around three real moments'),
      );
      expect(
        ThreeMomentActivationCopy.usesCautiousLanguage(
          ThreeMomentActivationCopy.momentThreeLine,
        ),
        isTrue,
      );
    });

    test('second moment return includes three-moment teaching', () {
      expect(
        SecondMomentReturnCopy.body,
        contains(ThreeMomentActivationCopy.momentThreeLine),
      );
    });

    test('first five minutes includes three-moment line', () {
      expect(
        FirstFiveMinutesSimplificationCopy.threeMomentLine,
        contains('Around three real moments'),
      );
    });
  });

  group('First-session promise — concrete but not overclaimed', () {
    test('record framing uses progressive zero-entry body', () {
      expect(
        RecordScreenFramingCopy.emptyArchiveBody,
        contains('returned, changed, faded, or corrected'),
      );
      expect(
        V1RevenueFocusPolicy.firstUserJourney,
        contains('Record one real moment'),
      );
    });

    test('first five minutes does not imply proof already exists', () {
      for (final line
          in FirstFiveMinutesSimplificationCopy.allVisibleStrings()) {
        expect(
          FirstFiveMinutesSimplificationCopy.previewImpliesProofExists(line),
          isFalse,
          reason: line,
        );
      }
    });

    test('sample archive tour teaches day 1-3 without overclaim', () {
      expect(SampleArchiveCopy.tourStep1Title.toLowerCase(), contains('day 1'));
      expect(SampleArchiveCopy.tourStep2Title.toLowerCase(), contains('day 2'));
      expect(SampleArchiveCopy.tourStep3Title.toLowerCase(), contains('day 3'));
      expect(
        SampleArchiveCopy.tourStep1Body.toLowerCase(),
        contains('example data only'),
      );
      expect(
        SampleArchiveCopy.tourStep3Body.toLowerCase(),
        anyOf(contains('can'), contains('cautiously')),
      );
    });
  });

  group('Pro copy sells longer proof trail, not AI', () {
    final proStrings = [
      PaywallAlignmentCopy.corePaidReason,
      PaywallValueSharpeningCopy.body,
      ProSinglePromiseCopy.body,
      ProConversionAuditCopy.proTrailCanonical,
      SaveARepeatHabitCopy.proLine,
      ...ProMemoryBoundaryCopy.allVisibleCopy(),
    ];

    test('pro strings avoid banned AI and medical claims', () {
      expect(ProConversionAuditCopy.hasNoBannedLiveClaims(proStrings), isTrue);
      expect(ProConversionAuditCopy.hasNoMedicalClaims(proStrings), isTrue);
      expect(
        ProConversionAuditCopy.mentionsPaidMemoryReason(proStrings),
        isTrue,
      );
    });

    test('pro single promise blocks more AI framing', () {
      expect(
        ProSinglePromiseCopy.notMoreAiLine.toLowerCase(),
        contains('not more chat or more ai'),
      );
    });
  });

  group('RevenueCat unavailable state is honest', () {
    test('live proof copy does not invent purchase success', () {
      expect(
        RevenueCatLiveProofCopy.guardrail.toLowerCase(),
        contains('do not treat automated tests as purchase proof'),
      );
      expect(
        RevenueCatLiveProofCopy.body.toLowerCase(),
        contains('sandbox purchase'),
      );
    });

    test('subscription unavailable copy stays calm', () {
      expect(
        ProMemoryBoundaryCopy.offeringsUnavailableBody.toLowerCase(),
        contains('app store products finish loading'),
      );
      expect(
        ProMemoryBoundaryCopy.offeringsUnavailableBody,
        isNot(contains('Pro is active')),
      );
    });
  });

  group('Future revenue directions are not live V1 promises', () {
    test('future scope lists deferred directions', () {
      expect(FutureRevenueScopeCopy.futureDirections, contains('exports'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('referrals'));
      expect(FutureRevenueScopeCopy.futureDirections, contains('safe sharing'));
    });

    test('private reports and exports use planned language', () {
      expect(
        RevenueValueCopy.privateReportBody.toLowerCase(),
        contains('planned'),
      );
      expect(
        RevenueValueCopy.exportBodyPlanned.toLowerCase(),
        contains('planned'),
      );
      expect(
        ProMemoryBoundaryCopy.privateReportPreviewBody.toLowerCase(),
        contains('not part of the v1 purchase promise'),
      );
    });
  });

  group('Safe sharing and referrals are not pre-proof growth loops', () {
    test('safe sharing frozen before proof', () {
      expect(
        SafeSharingFutureCopy.sharingFrozenLine.toLowerCase(),
        contains('not a v1 growth loop'),
      );
      expect(
        SafeSharingFutureCopy.ruleLabelFor(
          SafeSharingFutureRuleId.noSharingBeforeFirstUsefulProof,
        ),
        contains('before first useful proof'),
      );
    });

    test('referrals blocked before proof value', () {
      expect(
        ReferralAfterProofCopy.referralBlockedLine.toLowerCase(),
        contains('frozen until'),
      );
      expect(
        ReferralAfterProofCopy.ruleLabelFor(
          ReferralAfterProofRuleId.onlyAfterProofValue,
        ),
        contains('after useful proof'),
      );
    });
  });

  group('Acquisition wedge copy points into record-return-proof', () {
    test('primary wedge is prove enough', () {
      expect(LoopAcquisitionCopy.primaryWedge.id, 'prove_enough');
      expect(LoopAcquisitionCopy.proveEnough.isPrimaryWedge, isTrue);
    });

    test('wedge routes use record-return-proof promise', () {
      expect(
        LoopAcquisitionCopy.wedgeRoutePromise,
        'Save the moments where this happens. See whether it repeats.',
      );
      expect(
        LoopAcquisitionCopy.proveEnough.subheadline,
        LoopAcquisitionCopy.wedgeRoutePromise,
      );
      expect(
        LoopAcquisitionCopy.capacityYes.subheadline,
        LoopAcquisitionCopy.wedgeRoutePromise,
      );
    });

    test('habit copy teaches save-compare loop', () {
      expect(
        AudienceWedgeHabitCopy.saveLine,
        contains('ArchiveMe compares it later'),
      );
      expect(
        AudienceWedge.doingMoreToFeelEnough.firstPrompt,
        contains('save one real moment'),
      );
    });
  });

  group('No clinical or ChatGPT replacement claims', () {
    final consumerStrings = [
      ...SaveARepeatHabitCopy.allVisibleStrings(),
      ...AudienceWedgeHabitCopy.allVisibleStrings(),
      SubscriptionCopy.temporarilyUnavailable,
    ];

    test('consumer strings avoid banned pro and medical claims', () {
      expect(
        V1RevenueFocusPolicy.hasNoBannedLiveProClaims(consumerStrings),
        isTrue,
      );
      expect(
        ProConversionAuditCopy.hasNoMedicalClaims(consumerStrings),
        isTrue,
      );
    });
  });

  group('Beta expansion proof gate', () {
    test('lists required thresholds before expansion', () {
      expect(
        BetaExpansionProofCopy.requiredBeforeExpansion,
        contains('20 invites'),
      );
      expect(
        BetaExpansionProofCopy.requiredBeforeExpansion,
        contains('10 installs'),
      );
      expect(
        BetaExpansionProofCopy.requiredBeforeExpansion,
        contains('5 users with 3 real moments'),
      );
      expect(
        BetaExpansionProofCopy.requiredBeforeExpansion,
        contains(
          '2 willingness-to-pay signals for keeping the longer proof trail',
        ),
      );
    });

    test('retention metrics stay diagnostic only', () {
      expect(
        BetaExpansionProofCopy.retentionMetricsOnly,
        contains('day-2 return'),
      );
      expect(
        BetaExpansionProofCopy.guardrail.toLowerCase(),
        contains('metrics-only'),
      );
    });
  });

  group('Free/pro history split uses short history ceiling language', () {
    test('pro memory boundary avoids locked secret framing', () {
      expect(
        ProMemoryBoundaryCopy.freeHistoryLine.toLowerCase(),
        contains('recent proof'),
      );
      expect(
        ProMemoryBoundaryCopy.proHistoryLine.toLowerCase(),
        contains('longer proof trail'),
      );
      expect(
        ProMemoryBoundaryCopy.privateReportPreviewBody.toLowerCase(),
        isNot(contains('locked secret')),
      );
    });
  });
}
