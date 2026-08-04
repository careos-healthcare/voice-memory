import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_engine.dart';
import 'package:voicememory_mobile/billing/paywall_trigger_model.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';

void main() {
  const free = EntitlementSnapshot.free();
  const proofDelivered = ProductValueState(
    generatedCapabilities: {CapabilityId.firstEarlyComparison},
  );

  test('original content never produces a paywall at any archive size', () {
    for (final count in [1, 3, 7, 50, 1000]) {
      for (final capability in [
        CapabilityId.openOriginalEntry,
        CapabilityId.playOriginalAudio,
        CapabilityId.browseOriginalArchive,
        CapabilityId.basicLocalSearch,
        CapabilityId.exportOriginalContent,
        CapabilityId.deleteOriginalContent,
      ]) {
        expect(
          buildPaywallTrigger(
            capability: capability,
            entitlement: free,
            valueState: proofDelivered,
            momentCount: count,
          ),
          isNull,
        );
      }
    }
  });

  test('main paywall waits for the first valid comparison', () {
    expect(
      buildPaywallTrigger(
        capability: CapabilityId.advancedEvidenceGrouping,
        entitlement: free,
        valueState: const ProductValueState(),
      ),
      isNull,
    );
    expect(
      buildPaywallTrigger(
        capability: CapabilityId.advancedEvidenceGrouping,
        entitlement: free,
        valueState: proofDelivered,
      )?.trigger,
      PaywallTrigger.patternMapFull,
    );
  });

  test('explicit Pro entry may show before proof but Pro access bypasses', () {
    expect(
      buildPaywallTrigger(
        capability: CapabilityId.advancedEvidenceGrouping,
        entitlement: free,
        valueState: const ProductValueState(),
        explicitlyRequestedPro: true,
      )?.trigger,
      PaywallTrigger.patternMapFull,
    );
    expect(
      buildPaywallTrigger(
        capability: CapabilityId.advancedEvidenceGrouping,
        entitlement: const EntitlementSnapshot(
          plan: PlanKind.pro,
          status: EntitlementStatus.active,
        ),
        valueState: proofDelivered,
      ),
      isNull,
    );
  });

  test('existing generated output and free proof never trigger', () {
    for (final capability in [
      CapabilityId.readExistingGeneratedOutput,
      CapabilityId.firstEvidenceObservation,
      CapabilityId.firstEarlyComparison,
    ]) {
      expect(
        buildPaywallTrigger(
          capability: capability,
          entitlement: const EntitlementSnapshot(
            plan: PlanKind.pro,
            status: EntitlementStatus.expired,
          ),
          valueState: proofDelivered,
        ),
        isNull,
      );
    }
  });
}
