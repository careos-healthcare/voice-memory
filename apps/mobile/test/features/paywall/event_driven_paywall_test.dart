import 'package:archiveme_mobile/billing/archive_entitlement_reader.dart';
import 'package:archiveme_mobile/billing/archive_pro_feature_map.dart';
import 'package:archiveme_mobile/billing/magic_moments_counter.dart';
import 'package:archiveme_mobile/billing/paywall_access.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_engine.dart';
import 'package:archiveme_mobile/billing/paywall_trigger_model.dart';
import 'package:archiveme_mobile/core/config/v1_billing_capability.dart';
import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory journey state for magic-moment paywall timing.
///
/// Production does **not** take [sessionCount] — there is no N-session timer.
/// Case 1 still labels a first-session / cold-start analogue as
/// `sessionCount = 1` with [evidenceMilestones] = 0.
class _PaywallJourneyState {
  _PaywallJourneyState({
    this.sessionCount = 1,
    this.evidenceMilestones = 0,
    this.firstLoopClosed = false,
    this.hasSeenFirstRepeat = false,
    this.hasOpenedEvidenceTrail = false,
    this.isPro = false,
  });

  /// Label only — not read by [PaywallAccess] or [buildPaywallTrigger].
  final int sessionCount;
  int evidenceMilestones;
  bool firstLoopClosed;
  bool hasSeenFirstRepeat;
  bool hasOpenedEvidenceTrail;
  bool isPro;
}

void main() {
  late _PaywallJourneyState state;

  setUp(() async {
    await DelayedPaywallProofStore.resetForTest();
    state = _PaywallJourneyState();
  });

  tearDown(() async {
    await DelayedPaywallProofStore.resetForTest();
  });

  Future<PaywallTriggerContext?> evaluateCheck() => PaywallAccess.check(
    feature: ArchiveFeature.patternMap,
    entitlementReader: FakeArchiveEntitlementReader(pro: state.isPro),
    firstLoopClosed: state.firstLoopClosed,
    magicMomentsCount: state.evidenceMilestones,
    // Injected so magic-moment gates can run without flipping storeBilling.
    isBillingReachable: true,
  );

  Future<bool> evaluateCanOpen() {
    DelayedPaywallProofStore.seedForTest(
      hasSeenFirstRepeat: state.hasSeenFirstRepeat,
      hasOpenedEvidenceTrail: state.hasOpenedEvidenceTrail,
    );
    return PaywallAccess.canOpenPaywall(
      isBillingReachable: true,
      evidenceMilestoneCount: state.evidenceMilestones,
    );
  }

  PaywallTriggerContext? evaluateTrigger() => buildPaywallTrigger(
    feature: ArchiveFeature.patternMap,
    isPro: state.isPro,
    firstLoopClosed: state.firstLoopClosed,
    magicMomentsCount: state.evidenceMilestones,
    isBillingReachable: true,
  );

  test('storeBilling stays off — tests inject billing reachability', () {
    expect(V1CapabilityRegistry.storeBilling, isFalse);
    expect(V1BillingCapability.isProductionReachable, isFalse);
    expect(V1BillingCapability.isEnabled, isFalse);
  });

  test(
    'Case 1 — App Launch & Early Sessions: no paywall on cold start',
    () async {
      // sessionCount is not a production input. Cold start = 0 evidence
      // milestones (first-session analogue).
      expect(state.sessionCount, 1);
      expect(state.evidenceMilestones, 0);
      expect(state.firstLoopClosed, isFalse);

      expect(await evaluateCheck(), isNull);
      expect(evaluateTrigger(), isNull);
      expect(await evaluateCanOpen(), isFalse);

      // Production path (no injection) is also closed — no launch paywall.
      expect(
        await PaywallAccess.check(
          feature: ArchiveFeature.patternMap,
          firstLoopClosed: false,
          magicMomentsCount: 0,
        ),
        isNull,
      );
      expect(await PaywallAccess.canOpenPaywall(), isFalse);

      // First loop closed still does not fire with 0 milestones.
      state.firstLoopClosed = true;
      expect(await evaluateCheck(), isNull);
      expect(evaluateTrigger(), isNull);
    },
  );

  test(
    'Case 2 — Magic Moment Reached: three evidence milestones meet threshold',
    () {
      state.evidenceMilestones = 3;
      expect(MagicMomentsCounter.paywallThreshold, 3);
      expect(
        MagicMomentsCounter.paywallEligible(state.evidenceMilestones),
        isTrue,
      );
      expect(MagicMomentsCounter.paywallEligible(2), isFalse);
    },
  );

  test(
    'Case 3 — Trigger Verification: paywall only after value delivery',
    () async {
      // Explicit cold-start re-check: 0 milestones never opens the paywall.
      expect(state.evidenceMilestones, 0);
      expect(await evaluateCheck(), isNull);
      expect(evaluateTrigger(), isNull);
      expect(await evaluateCanOpen(), isFalse);

      // Value delivered: 3 evidence milestones (not session 2/3).
      state.evidenceMilestones = 3;
      expect(
        MagicMomentsCounter.paywallEligible(state.evidenceMilestones),
        isTrue,
      );

      // Trigger evaluator also requires first loop closed and not Pro.
      state.firstLoopClosed = true;
      state.isPro = false;

      // canOpenPaywall additionally requires first-repeat + evidence-trail
      // opened (DelayedPaywallProofStore.passesGate) — not a session timer.
      state.hasSeenFirstRepeat = true;
      state.hasOpenedEvidenceTrail = true;

      final trigger = evaluateTrigger();
      expect(trigger, isNotNull);
      expect(trigger!.trigger, PaywallTrigger.patternMapFull);

      final checked = await evaluateCheck();
      expect(checked, isNotNull);
      expect(checked!.trigger, PaywallTrigger.patternMapFull);

      expect(await evaluateCanOpen(), isTrue);

      // Without the delayed-proof flags, canOpen stays closed even after
      // the magic-moment threshold — still not a session-count trigger.
      state.hasSeenFirstRepeat = false;
      state.hasOpenedEvidenceTrail = false;
      expect(await evaluateCanOpen(), isFalse);
    },
  );
}
